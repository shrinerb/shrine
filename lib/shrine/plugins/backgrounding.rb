# frozen_string_literal: true

class Shrine
  module Plugins
    # The `backgrounding` plugin enables you to move promoting and deleting of
    # files from record's lifecycle into background jobs. This is especially
    # useful if you're doing processing and/or you're storing files on an
    # external storage service.
    #
    # The plugin provides `Attacher.promote` and `Attacher.delete` methods,
    # which allow you to hook up to promoting and deleting and spawn background
    # jobs, by passing a block.
    #
    #     Shrine.plugin :backgrounding
    #
    #     # makes all uploaders use background jobs
    #     Shrine::Attacher.promote { |data| PromoteJob.perform_async(data) }
    #     Shrine::Attacher.delete { |data| DeleteJob.perform_async(data) }
    #
    # If you don't want to apply backgrounding for all uploaders, you can
    # declare the hooks only for specific uploaders (in this case it's still
    # recommended to keep the plugin loaded globally).
    #
    #     class MyUploader < Shrine
    #       # makes this uploader use background jobs
    #       Attacher.promote { |data| PromoteJob.perform_async(data) }
    #       Attacher.delete { |data| DeleteJob.perform_async(data) }
    #     end
    #
    # The yielded `data` variable is a serializable hash containing all context
    # needed for promotion/deletion. Now you just need to declare the job
    # classes, and inside them call `Attacher.promote` or `Attacher.delete`,
    # this time with the received data.
    #
    #     class PromoteJob
    #       include Sidekiq::Worker
    #       def perform(data)
    #         Shrine::Attacher.promote(data)
    #       end
    #     end
    #
    #     class DeleteJob
    #       include Sidekiq::Worker
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
    # In your application you can use `Attacher#cached?` and `Attacher#stored?`
    # to differentiate between your background job being in progress and
    # having completed.
    #
    #     if user.avatar_attacher.cached? # background job is still in progress
    #       # ...
    #     elsif user.avatar_attacher.stored? # background job has finished
    #       # ...
    #     end
    #
    # ## `Attacher.promote` and `Attacher.delete`
    #
    # In background jobs, `Attacher.promote` and `Attacher.delete` will resolve
    # all necessary objects, and do the promotion/deletion. If
    # `Attacher.find_record` is defined (which comes with ORM plugins), model
    # instances will be treated as database records, with the `#id` attribute
    # assumed to represent the primary key. Then promotion will have the
    # following behaviour:
    #
    # 1. retrieves the database record
    #     * if record is not found, it finishes
    #     * if record is found but attachment has changed, it finishes
    # 2. uploads cached file to permanent storage
    # 3. reloads the database record
    #     * if record is not found, it deletes the promoted files and finishes
    #     * if record is found but attachment has changed, it deletes the promoted files and finishes
    # 4. updates the record with the promoted files
    #
    # Both `Attacher.promote` and `Attacher.delete` return a `Shrine::Attacher`
    # instance (if the action hasn't aborted), so you can use it to perform
    # additional tasks:
    #
    #     def perform(data)
    #       attacher = Shrine::Attacher.promote(data)
    #       attacher.record.update(published: true) if attacher && attacher.record.is_a?(Post)
    #     end
    #
    # ### Plain models
    #
    # You can also do backgrounding with plain models which don't represent
    # database records; the plugin will use that mode if `Attacher.find_record`
    # is not defined. In that case promotion will have the following behaviour:
    #
    # 1. instantiates the model
    # 2. uploads cached file to permanent storage
    # 3. writes promoted files to the model instance
    #
    # You can then retrieve the promoted files via the attacher object that
    # `Attacher.promote` returns, and do any additional tasks if you need to.
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
          record = load_record(data)
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

        # Resolves the record from backgrounding data. If the record was found,
        # returns it. If the record wasn't found, returns an instance of the
        # model with ID assigned for logging. If `find_record` isn't defined,
        # then it is a PORO model and should be instantiated with the cached
        # attachment.
        def load_record(data)
          record_class, record_id = data["record"]
          record_class = Object.const_get(record_class)

          if respond_to?(:find_record)
            record   = find_record(record_class, record_id)
            record ||= record_class.new.tap do |instance|
              # so that the id is always included in file deletion logs
              instance.singleton_class.send(:define_method, :id) { record_id }
            end
          else
            record = record_class.new
            record.send(:"#{data["name"]}_data=", data["attachment"])
          end

          record
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
          if self.class.respond_to?(:find_record)
            reloaded = self.class.find_record(record.class, record.id)
            return if reloaded.nil? || self.class.new(reloaded, name).read != read
          end
          super
        end
      end
    end

    register_plugin(:backgrounding, Backgrounding)
  end
end
