class Shrine
  module Plugins
    # The backup plugin allows you to automatically backup up stored files to
    # an additional storage.
    #
    #     storages[:backup_store] = Shrine::Storage::S3.new(options)
    #     plugin :backup, storage: :backup_store
    #
    # After the cached file is promoted to store, it will be reuploaded from
    # store to the provided "backup" storage.
    #
    #     user.update(avatar: file) # uploaded both to :store and :backup_store
    #
    # By default whenever stored files are deleted backed up files are deleted
    # as well, but you can keep files on the "backup" storage by passing
    # `delete: false`:
    #
    #     plugin :backup, storage: :backup_store, delete: false
    #
    # Note that when adding this plugin with already existing stored files,
    # Shrine won't know whether a stored file is backed up or not, so
    # attempting to delete the backup could result in an error. To avoid that
    # you can set `delete: false` until you manually back up the existing
    # stored files.
    module Backup
      def self.configure(uploader, storage:, delete: true)
        uploader.opts[:backup_storage] = storage
        uploader.opts[:backup_delete] = delete
      end

      module AttacherMethods
        # Backs up the stored file after promoting.
        def promote(*)
          result = super
          store_backup!(result) if result
          result
        end

        # Deletes the backup file in addition to the stored file.
        def replace
          result = super
          delete_backup!(@old) if result && delete_backup?
          result
        end

        # Deletes the backup file in addition to the stored file.
        def destroy
          result = super
          delete_backup!(get) if result && delete_backup?
          result
        end

        # Returns a copy of the given uploaded file with storage changed to
        # backup storage.
        def backup_file(uploaded_file)
          uploaded_file(uploaded_file.to_json) do |file|
            file.data["storage"] = backup_storage.to_s
          end
        end

        private

        # Upload the stored file to the backup storage.
        def store_backup!(stored_file)
          backup_store.upload(stored_file, context.merge(phase: :backup))
        end

        # Deleted the stored file from the backup storage.
        def delete_backup!(deleted_file)
          delete!(backup_file(deleted_file), phase: :backup)
        end

        def backup_store
          @backup_store ||= shrine_class.new(backup_storage)
        end

        def backup_storage
          shrine_class.opts[:backup_storage]
        end

        def delete_backup?
          shrine_class.opts[:backup_delete]
        end
      end

      module InstanceMethods
        private

        # We preserve the location when uploading from store to backup.
        def get_location(io, context)
          if context[:phase] == :backup
            io.id
          else
            super
          end
        end
      end
    end

    register_plugin(:backup, Backup)
  end
end
