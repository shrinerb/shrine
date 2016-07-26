class Shrine
  module Plugins
    # The delete_raw plugin will automatically delete raw files that have been
    # uploaded. This is especially useful when doing processing, to ensure that
    # temporary files have been deleted after upload.
    #
    #     plugin :delete_raw
    #
    # By default any raw file that was uploaded will be deleted, but you can
    # limit this only to files uploaded to certain storages:
    #
    #     plugin :delete_raw, storages: [:store]
    module DeleteRaw
      def self.configure(uploader, opts = {})
        uploader.opts[:delete_raw_storages] = opts.fetch(:storages, uploader.opts[:delete_raw_storages])
      end

      module InstanceMethods
        private

        # Deletes the file that was uploaded, unless it's an UploadedFile.
        def copy(io, context)
          super
          if io.respond_to?(:delete) && !io.is_a?(UploadedFile)
            io.delete rescue nil if delete_uploaded?(io)
          end
        end

        def delete_uploaded?(io)
          opts[:delete_raw_storages].nil? ||
          opts[:delete_raw_storages].include?(storage_key)
        end
      end
    end

    register_plugin(:delete_raw, DeleteRaw)
  end
end
