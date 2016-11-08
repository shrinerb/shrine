class Shrine
  module Plugins
    # The `backgrounding` plugin enables you to move promoting and deleting of
    # files from record's lifecycle into background jobs. This is especially
    # useful if you're doing processing and/or you're storing files on an
    # external storage service.
    #
    #     plugin :backgrounding
    #
    # ## Usage
    #
    # The plugin provides `Attacher.promote` and `Attacher.delete` methods,
    # which allow you to hook up to promoting and deleting and spawn background
    # jobs, by passing a block.
    #
    #     Shrine::Attacher.promote { |data| PromoteJob.perform_async(data) }
    #     Shrine::Attacher.delete { |data| DeleteJob.perform_async(data) }
    #
    # The yielded `data` variable is a serializable hash containing all context
    # needed for promotion/deletion. Now you just need to declare the job
    # classes, and inside them call `Attacher.promote` or `Attacher.delete`,
    # this time with the received data.
    #
    #     class PromoteJob
    #       include Sidekiq::Worker
    #
    #       def perform(data)
    #         Shrine::Attacher.promote(data)
    #       end
    #     end
    #
    #     class DeleteJob
    #       include Sidekiq::Worker
    #
    #       def perform(data)
    #         Shrine::Attacher.delete(data)
    #       end
    #     end
    #
    # This example used Sidekiq, but obviously you could just as well use
    # any other backgrounding library. This setup will be applied globally for
    # all uploaders.
    #
    # If you're generating versions, and you want to process some versions in
    # the foreground before kicking off a background job, you can use the
    # `recache` plugin.
    #
    # ## `Attacher.promote` and `Attacher.delete`
    #
    # Internally `Attacher.promote` and `Attacher.delete` will resolve all
    # necessary objects and do the promotion/deletion. Deletion will always
    # perform the same way, while promotion has the following behaviour:
    #
    # * retrieves the database record
    #     * if record is not found, it finishes
    #     * otherwise if fetched attachment doesn't match received, it finishes
    # * uploads cached file to permanent storage
    # * reloads the database record
    #     * if record is not found, it deletes the uploaded files and finishes
    #     * otherwise if fetched attachment doesn't match received, it deletes the uploaded files and finishes
    # * updates the record with permanently stored files
    #
    # The methods rely on `find_record` method being defined on the `Attacher`
    # class, which normally come with the ORM plugins. It is also assumes that
    # the `#id` attribute of the model instance represents a unique identifier.
    #
    # Both methods return a `Shrine::Attacher` instance (if the action hasn't
    # aborted), so you can use it to perform additional tasks:
    #
    #     def perform(data)
    #       attacher = Shrine::Attacher.promote(data)
    #       attacher.record.update(published: true) if attacher && attacher.record.is_a?(Post)
    #     end
    #
    # ## `Attacher#_promote` and `Attacher#_delete`
    #
    # The plugin modifies `Attacher#_promote` and `Attacher#_delete` to call
    # the registered blocks with serializable attacher data, and these methods
    # are internally called by the attacher. `Attacher#promote` and
    # `Attacher#delete!` remain synchronous.
    #
    #     # asynchronous (spawn background jobs)
    #     attacher._promote
    #     attacher._delete(attachment)
    #
    #     # synchronous
    #     attacher.promote
    #     attacher.delete!(attachment)
    #
    # ## `Attacher.dump` and `Attacher.load`
    #
    # The plugin adds `Attacher.dump` and `Attacher.load` methods for
    # serializing attacher object and loading it back up. You can use them to
    # spawn background jobs for custom tasks.
    #
    #     data = Shrine::Attacher.dump(attacher)
    #     SomethingJob.perform_async(data)
    #
    #     # ...
    #
    #     class SomethingJob
    #       def perform(data)
    #         attacher = Shrine::Attacher.load(data)
    #         # ...
    #       end
    #     end
    module Backgrounding
      module AttacherClassMethods
        # If block is passed in, stores it to be called on promotion. Otherwise
        # resolves data into objects and calls `Attacher#promote`.
        def promote(data = nil, &block)
          if block
            shrine_class.opts[:backgrounding_promote] = block
          else
            attacher = load(data)
            cached_file = attacher.uploaded_file(data["attachment"])
            action = data["action"].to_sym if data["action"]

            return if cached_file != attacher.get
            attacher.promote(cached_file, action: action) or return

            attacher
          end
        end

        # If block is passed in, stores it to be called on deletion. Otherwise
        # resolves data into objects and calls `Shrine#delete`.
        def delete(data = nil, &block)
          if block
            shrine_class.opts[:backgrounding_delete] = block
          else
            attacher = load(data)
            uploaded_file = attacher.uploaded_file(data["attachment"])
            action = data["action"].to_sym if data["action"]

            attacher.delete!(uploaded_file, action: action)

            attacher
          end
        end

        # Delegates to `Attacher#dump`.
        def dump(attacher)
          attacher.dump
        end

        # Loads the data created by #dump, resolving the record and returning
        # the attacher.
        def load(data)
          record_class, record_id = data["record"]
          record_class = Object.const_get(record_class)

          record   = find_record(record_class, record_id)
          record ||= record_class.new.tap do |instance|
            # so that the id is always included in file deletion logs
            instance.singleton_class.send(:define_method, :id) { record_id }
          end

          name = data["name"].to_sym

          if data["shrine_class"]
            shrine_class = Object.const_get(data["shrine_class"])
            attacher = shrine_class::Attacher.new(record, name)
          else
            # anonymous uploader class, try to retrieve attacher from record
            attacher = record.send("#{name}_attacher")
          end

          attacher
        end
      end

      module AttacherMethods
        # Calls the promoting block (if registered) with a serializable data
        # hash.
        def _promote(uploaded_file = get, phase: nil, action: phase)
          if background_promote = shrine_class.opts[:backgrounding_promote]
            data = self.class.dump(self).merge(
              "attachment" => uploaded_file.to_json,
              "action"     => (action.to_s if action),
              "phase"      => (action.to_s if action), # legacy
            )
            instance_exec(data, &background_promote)
          else
            super
          end
        end

        # Calls the deleting block (if registered) with a serializable data
        # hash.
        def _delete(uploaded_file, phase: nil, action: phase)
          if background_delete = shrine_class.opts[:backgrounding_delete]
            data = self.class.dump(self).merge(
              "attachment" => uploaded_file.to_json,
              "action"     => (action.to_s if action),
              "phase"      => (action.to_s if action), # legacy
            )
            instance_exec(data, &background_delete)
            uploaded_file
          else
            super
          end
        end

        # Dumps all the information about the attacher in a serializable hash
        # suitable for passing as an argument to background jobs.
        def dump
          {
            "attachment"   => (get && get.to_json),
            "record"       => [record.class.to_s, record.id.to_s],
            "name"         => name.to_s,
            "shrine_class" => shrine_class.name,
          }
        end

        # Updates with the new file only if the attachment hasn't changed.
        def swap(new_file)
          reloaded = self.class.find_record(record.class, record.id)
          return if reloaded.nil? || self.class.new(reloaded, name).read != read
          super
        end
      end
    end

    register_plugin(:backgrounding, Backgrounding)
  end
end
