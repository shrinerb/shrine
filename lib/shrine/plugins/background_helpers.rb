class Shrine
  module Plugins
    # The background_helpers plugin enables you to intercept phases of
    # uploading and put them into background jobs. This doesn't require any
    # additional columns.
    #
    #     plugin :background_helpers
    #
    # ## Promoting
    #
    # If you're doing processing, or your `:store` is something other than
    # Storage::FileSystem, it's recommended to put promoting (moving to store)
    # into a background job. This plugin allows you to do that by calling
    # `Shrine::Attacher.promote`:
    #
    #     Shrine::Attacher.promote { |data| UploadJob.perform_async(data) }
    #
    # When you call `Shrine::Attacher.promote` with a block, it will save the
    # block and call it on every promotion. Then in your background job you can
    # again call `Shrine::Attacher.promote` with the data, and internally it
    # will resolve all necessary objects, do the promoting and update the
    # record.
    #
    #     class UploadJob
    #       include Sidekiq::Worker
    #
    #       def perform(data)
    #         Shrine::Attacher.promote(data)
    #       end
    #     end
    #
    # Shrine automatically handles all concurrency issues, such as canceling
    # promoting if the attachment has changed in the meanwhile.
    #
    # ## Deleting
    #
    # If your `:store` is something other than Storage::FileSystem, it's
    # recommended to put deleting files into a background job. This plugin
    # allows you to do that by calling `Shrine::Attacher.delete`:
    #
    #     Shrine::Attacher.delete { |data| DeleteJob.perform_async(data) }
    #
    # When you call `Shrine::Attacher.delete` with a block, it will save the
    # block and call it on every delete. Then in your background job you can
    # again call `Shrine::Attacher.delete` with the data, and internally it
    # will resolve all necessary objects, and delete the file.
    #
    #     class DeleteJob
    #       include Sidekiq::Worker
    #
    #       def perform(data)
    #         Shrine::Attacher.delete(data)
    #       end
    #     end
    #
    # ## Conclusion
    #
    # The examples above used Sidekiq, but obviously you can just as well use
    # any other backgrounding library. Also, if you want you can use
    # backgrounding just for certain uploaders:
    #
    #     class ImageUploader < Shrine
    #       Attacher.promote { |data| UploadJob.perform_async(data) }
    #       Attacher.delete { |data| DeleteJob.perform_async(data) }
    #     end
    #
    # If you would like to speed up your uploads and deletes, you can use the
    # parallelize plugin, either as a replacement or an addition to
    # background_helpers.
    module BackgroundHelpers
      module AttacherClassMethods
        # If block is passed in, stores it to be called on promotion. Otherwise
        # resolves data into objects and calls Attacher#promote.
        def promote(data = nil, &block)
          if block
            shrine_class.opts[:background_promote] = block
          else
            record_class, record_id = data["record"]
            record_class = Object.const_get(record_class)
            record = find_record(record_class, record_id)

            name = data["attachment"]
            attacher = record.send("#{name}_attacher")
            cached_file = attacher.uploaded_file(data["uploaded_file"])

            attacher.promote(cached_file)
          end
        end

        # If block is passed in, stores it to be called on deletion. Otherwise
        # resolves data into objects and calls `Shrine#delete`.
        def delete(data = nil, &block)
          if block
            shrine_class.opts[:background_delete] = block
          else
            record_class, record_id = data["record"]
            record = Object.const_get(record_class).new
            record.id = record_id

            name, phase = data["attachment"], data["phase"]
            attacher = record.send("#{name}_attacher")
            uploaded_file = attacher.uploaded_file(data["uploaded_file"])
            context = {name: name.to_sym, record: record, phase: phase.to_sym}

            attacher.store.delete(uploaded_file, context)
          end
        end
      end

      module AttacherMethods
        # Calls the promoting block with the data if it's been registered.
        def _promote
          if background_promote = shrine_class.opts[:background_promote]
            data = {
              "uploaded_file" => get.to_json,
              "record"        => [record.class.to_s, record.id],
              "attachment"    => name,
            }

            instance_exec(data, &background_promote) if promote?(get)
          else
            super
          end
        end

        private

        # Calls the deleting block with the data if it's been registered.
        def delete!(uploaded_file, phase:)
          if background_delete = shrine_class.opts[:background_delete]
            data = {
              "uploaded_file" => uploaded_file.to_json,
              "record"        => [record.class.to_s, record.id],
              "attachment"    => name,
              "phase"         => phase,
            }

            instance_exec(data, &background_delete)
          else
            super(uploaded_file, phase: phase)
          end
        end
      end
    end

    register_plugin(:background_helpers, BackgroundHelpers)
  end
end
