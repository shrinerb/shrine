class Shrine
  module Plugins
    # The delete_uploaded plugin will automatically delete files after they
    # have been uploaded. This is especially useful when doing processing, to
    # ensure that temporary files have been deleted after upload. One exception
    # are `Shrine::UploadedFile` files, they won't get deleted for stability
    # reasons.
    #
    #     plugin :delete_uploaded
    #
    # By default this behaviour will be applied to all storages, but you can
    # limit this only to specified storages:
    #
    #     plugin :delete_uploaded, storages: [:store]
    module DeleteUploaded
      def self.configure(uploader, storages: :all)
        uploader.opts[:delete_uploaded_storages] = storages
      end

      module InstanceMethods
        private

        # Deletes the uploaded file unless it's an UploadedFile.
        def copy(io, context)
          super
          if io.respond_to?(:delete) && !io.is_a?(UploadedFile)
            io.delete if delete_uploaded?(io)
          end
        end

        def delete_uploaded?(io)
          opts[:delete_uploaded_storages] == :all ||
          opts[:delete_uploaded_storages].include?(storage_key)
        end
      end
    end

    register_plugin(:delete_uploaded, DeleteUploaded)
  end
end
