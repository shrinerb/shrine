class Shrine
  module Plugins
    # The background_helpers plugin enables you to intercept phases of
    # uploading in order to put them in background jobs.
    #
    #     plugin :background_helpers
    #
    # The examples will use Sidekiq, but you can just as well use any other
    # backgrounding library.
    #
    # If you're doing processing, or your `:store` is something other than
    # Storage::FileSystem, you may want to put promoting in a background job.
    # You can do that by calling `Shrine::Attacher.promote`:
    #
    #     class ImageUploader
    #       plugin :background_helpers
    #
    #       Attacher.promote do |cached_file|
    #         # Evaluated inside an instance of Shrine::Attacher.
    #         UploadJob.perform_async(cached_file, record.class, record.id, name)
    #       end
    #     end
    #
    # And then the promoting job can look like this:
    #
    #     class UploadJob
    #       include Sidekiq::Worker
    #
    #       def perform(cached_file_json, record_class, record_id, name)
    #         record = Object.const_get(record_class).find(record_id)
    #         attacher = record.send("#{name}_attacher")
    #         cached_file = attacher.uploaded_file(cached_file_json)
    #
    #         attacher.promote(cached_file)
    #         record.save
    #       end
    #     end
    #
    # Shrine will automatically eliminate all concurrency issues. For example,
    # it will terminate promoting if in the meanwhile the user has reuploaded
    # attachment.
    #
    # If your `:store` is something other than Storage::FileSystem, you may
    # want to put deleting of your files in a backgoround job. You can do that
    # by calling `Shrine::Attacher.delete`:
    #
    #     class ImageUploader
    #       plugin :background_helpers
    #
    #       Attacher.delete do |uploaded_file, phase:|
    #         # Evaluated inside an instance of Shrine::Attacher.
    #         DeleteJob.perform_async(uploaded_file, record.class, record.id, name, phase)
    #       end
    #     end
    #
    # And then the deleting job can look like this:
    #
    #     class DeleteJob
    #       include Sidekiq::Worker
    #
    #       def perform(uploaded_file_json, shrine_class, record_class, record_id, name, phase)
    #         record = Object.const_get(record_class).find(record_id)
    #         shrine_class = record.send("#{name}_attacher").shrine_class
    #         uploaded_file = shrine_class.uploaded_file(uploaded_file_json)
    #         context = {record: record, name: name.to_sym, promote: promote.to_sym}
    #
    #         shrine_class.delete(uploaded_file, context)
    #       end
    #     end
    #
    # Note that we're passing the context in order to imitate the flow how it
    # would look like if we didn't intercept it. For example, this gives the
    # logging plugin relevant context. Both jobs written like this will
    # automatically work with the versions plugin.
    #
    # If you would like to speed up your uploads and deletes, but you don't
    # want to involve background jobs, the parallelize plugin may be what you
    # want. You can also combine these two.
    module BackgroundHelpers
      module AttacherClassMethods
        # Saves the promoting block to be called later.
        def promote(&block)
          shrine_class.opts[:background_promote] = block
        end

        # Saves the deleting block to be called later.
        def delete(&block)
          shrine_class.opts[:background_delete] = block
        end
      end

      module AttacherMethods
        # Calls the promoting block if it's been registered.
        def _promote
          if background_promote = shrine_class.opts[:background_promote]
            instance_exec(get, &background_promote) if promote?(get)
          else
            super
          end
        end

        private

        # Calls the deleting block if it's been registered.
        def delete!(uploaded_file, phase:)
          if background_delete = shrine_class.opts[:background_delete]
            instance_exec(uploaded_file, phase: phase, &background_delete)
          else
            super
          end
        end
      end
    end

    register_plugin(:background_helpers, BackgroundHelpers)
  end
end
