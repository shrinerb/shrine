# frozen_string_literal: true

class Shrine
  module Plugins
    module Mirroring
      def self.configure(uploader, **opts)
        uploader.opts[:mirroring] ||= { upload: true, delete: true }
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

        def mirror_upload_block(&block)
          if block
            opts[:mirroring][:upload_block] = block
          else
            opts[:mirroring][:upload_block]
          end
        end

        def mirror_delete_block(&block)
          if block
            opts[:mirroring][:delete_block] = block
          else
            opts[:mirroring][:delete_block]
          end
        end

        def mirror_upload?
          opts[:mirroring][:upload]
        end

        def mirror_delete?
          opts[:mirroring][:delete]
        end
      end

      module InstanceMethods
        # Mirrors upload to other mirror storages.
        def upload(io, mirror: true, **options)
          file = super(io, **options)
          file.trigger_mirror_upload if mirror
          file
        end
      end

      module FileMethods
        # Mirrors upload if mirrors are defined. Calls mirror block if
        # registered, otherwise mirrors synchronously.
        def trigger_mirror_upload
          return unless shrine_class.mirrors[storage_key] && shrine_class.mirror_upload?

          if shrine_class.mirror_upload_block
            mirror_upload_background
          else
            mirror_upload
          end
        end

        # Calls mirror upload block.
        def mirror_upload_background
          fail Error, "mirror upload block is not registered" unless shrine_class.mirror_upload_block

          shrine_class.mirror_upload_block.call(self)
        end

        # Uploads the file to each mirror storage.
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

        # Mirrors delete to other mirror storages.
        def delete(mirror: true)
          result = super()
          trigger_mirror_delete if mirror
          result
        end

        # Mirrors delete if mirrors are defined. Calls mirror block if
        # registered, otherwise mirrors synchronously.
        def trigger_mirror_delete
          return unless shrine_class.mirrors[storage_key] && shrine_class.mirror_delete?

          if shrine_class.mirror_delete_block
            mirror_delete_background
          else
            mirror_delete
          end
        end

        # Calls mirror delete block.
        def mirror_delete_background
          fail Error, "mirror delete block is not registered" unless shrine_class.mirror_delete_block

          shrine_class.mirror_delete_block.call(self)
        end

        # Deletes the file from each mirror storage.
        def mirror_delete
          each_mirror do |mirror|
            self.class.new(id: id, storage: mirror).delete
          end
        end

        private

        # Iterates over mirror storages.
        def each_mirror(&block)
          mirrors = shrine_class.mirrors(storage_key)
          mirrors.map(&block)
        end
      end
    end

    register_plugin(:mirroring, Mirroring)
  end
end
