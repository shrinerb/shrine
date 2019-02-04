# frozen_string_literal: true

class Shrine
  module Plugins
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

          if record.respond_to?(:"#{name}_attacher")
            attacher = record.send(:"#{name}_attacher")
          elsif data["shrine_class"]
            shrine_class = Object.const_get(data["shrine_class"])
            attacher = shrine_class::Attacher.new(record, name)
          else
            fail Error, "cannot load anonymous uploader class"
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
            return if reloaded.nil?

            attacher   = reloaded.send(:"#{name}_attacher") if reloaded.respond_to?(:"#{name}_attacher")
            attacher ||= self.class.new(reloaded, name) # Shrine::Attachment is not used

            return if attacher.get != self.get
          end
          super
        end
      end
    end

    register_plugin(:backgrounding, Backgrounding)
  end
end
