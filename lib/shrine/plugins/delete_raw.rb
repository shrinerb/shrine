# frozen_string_literal: true

class Shrine
  module Plugins
    # The `delete_raw` plugin will automatically delete raw files that have been
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
          if io.respond_to?(:path) && io.path && delete_raw?
            begin
              File.delete(io.path)
            rescue Errno::ENOENT
              # file might already be deleted by the moving plugin
            end
          end
        end

        def delete_raw?
          opts[:delete_raw_storages].nil? ||
          opts[:delete_raw_storages].include?(storage_key)
        end
      end
    end

    register_plugin(:delete_raw, DeleteRaw)
  end
end
