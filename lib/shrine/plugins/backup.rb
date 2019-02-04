# frozen_string_literal: true

class Shrine
  module Plugins
    module Backup
      def self.configure(uploader, opts = {})
        uploader.opts[:backup_storage] = opts.fetch(:storage, uploader.opts[:backup_storage])
        uploader.opts[:backup_delete] = opts.fetch(:delete, uploader.opts.fetch(:backup_delete, true))

        raise Error, "The :storage option is required for backup plugin" if uploader.opts[:backup_storage].nil?
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
          options = _equalize_phase_and_action(action: :backup, move: false)
          backup_store.upload(stored_file, context.merge(options))
        end

        # Deleted the stored file from the backup storage.
        def delete_backup!(deleted_file)
          _delete(backup_file(deleted_file), action: :backup)
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
          if context[:action] == :backup
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
