# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/delete_raw.md] on GitHub.
    #
    # [doc/plugins/delete_raw.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/delete_raw.md
    module DeleteRaw
      def self.configure(uploader, opts = {})
        uploader.opts[:delete_raw_storages] = opts.fetch(:storages, uploader.opts[:delete_raw_storages])
      end

      module InstanceMethods
        private

        # Deletes the file that was uploaded, unless it's an UploadedFile.
        def copy(io, context)
          super
          if io.respond_to?(:path) && io.path && delete_raw? && context[:delete] != false
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
