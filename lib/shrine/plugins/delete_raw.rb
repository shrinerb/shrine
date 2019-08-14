# frozen_string_literal: true

Shrine.deprecation("The delete_raw plugin is deprecated and will be removed in Shrine 4. If you were using it with versions plugin, use the new derivatives plugin instead.")

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/delete_raw.md] on GitHub.
    #
    # [doc/plugins/delete_raw.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/delete_raw.md
    module DeleteRaw
      def self.configure(uploader, **opts)
        uploader.opts[:delete_raw] ||= {}
        uploader.opts[:delete_raw].merge!(opts)
      end

      module InstanceMethods
        private

        # Deletes the file that was uploaded, unless it's an UploadedFile.
        def _upload(io, delete: nil, **options)
          super(io, **options)

          if io.respond_to?(:path) && io.path && delete_raw? && delete != false
            begin
              File.delete(io.path)
            rescue Errno::ENOENT
              # file might already be deleted if it was moved
            end
          end
        end

        def delete_raw?
          opts[:delete_raw][:storages].nil? ||
          opts[:delete_raw][:storages].include?(storage_key)
        end
      end
    end

    register_plugin(:delete_raw, DeleteRaw)
  end
end
