# frozen_string_literal: true

class Shrine
  module Plugins
    module Mirroring
      UPLOAD = -> (uploaded_file) { uploaded_file.mirror_upload }
      DELETE = -> (uploaded_file) { uploaded_file.mirror_delete }

      def self.configure(uploader, **opts)
        uploader.opts[:mirroring] ||= { upload: UPLOAD, delete: DELETE }
        uploader.opts[:mirroring].merge!(opts)

        fail Error, ":mirror option is required for mirroring plugin" unless uploader.opts[:mirroring][:mirror]
      end

      module ClassMethods
        def mirrors(storage_key = nil)
          if storage_key
            mirrors = opts[:mirroring][:mirror][storage_key]

            fail Error, "no mirrors registered for storage #{storage_key.inspect}" unless mirrors

            Array(mirrors)
          else
            opts[:mirroring][:mirror]
          end
        end

        def mirror_upload(&block)
          if block
            opts[:mirroring][:upload] = block
          else
            opts[:mirroring][:upload]
          end
        end

        def mirror_delete(&block)
          if block
            opts[:mirroring][:delete] = block
          else
            opts[:mirroring][:delete]
          end
        end
      end

      module InstanceMethods
        def upload(io, **options)
          uploaded_file = super

          if self.class.mirrors[storage_key] && self.class.mirror_upload
            self.class.mirror_upload.call(uploaded_file)
          end

          uploaded_file
        end
      end

      module FileMethods
        def mirror_upload
          previously_opened = opened?

          each_mirror do |mirror|
            rewind if opened?

            shrine_class.upload(self, mirror, location: id, close: false)
          end
        ensure
          if opened? && !previously_opened
            close
            @io = nil
          end
        end

        def delete
          result = super

          if shrine_class.mirrors[storage_key] && shrine_class.mirror_delete
            shrine_class.mirror_delete.call(self)
          end

          result
        end

        def mirror_delete
          each_mirror do |mirror|
            self.class.new(id: id, storage: mirror).delete
          end
        end

        private

        def each_mirror(&block)
          mirrors = shrine_class.mirrors(storage_key)
          mirrors.map(&block)
        end
      end
    end

    register_plugin(:mirroring, Mirroring)
  end
end
