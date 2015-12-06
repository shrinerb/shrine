class Shrine
  module Plugins
    # The backup plugin allows you to automatically backup up stored files to
    # an additional storage. After the cached file is promoted to store, it
    # will be reuploaded from store to the provided "backup" storage.
    #
    #     storages[:backup_store] = Shrine::Storage::S3.new(options)
    #
    #     plugin :backup, storage: :backup_store
    module Backup
      def self.configure(uploader, storage:)
        uploader.opts[:backup_storage] = storage
      end

      module AttacherMethods
        def store!(io, phase:)
          stored_file = super
          backup_store.upload(stored_file, context.merge(phase: phase))
        end

        private

        def backup_store
          @backup_store ||= shrine_class.new(shrine_class.opts[:backup_storage])
        end
      end
    end

    register_plugin(:backup, Backup)
  end
end
