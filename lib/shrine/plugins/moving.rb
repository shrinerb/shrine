class Shrine
  module Plugins
    # The moving plugin makes so that when files are supposed to be uploaded,
    # they are moved instead. For example, on FileSystem moving is
    # instantaneous regardless of the filesize, so it's suitable for speeding
    # up uploads for larger files.
    #
    #     plugin :moving
    #
    # By default files will be moved whenever the storage supports it. If you
    # want moving to happen only for certain storages, you can set `storages`:
    #
    #     plugin :moving, storages: [:cache]
    module Moving
      def self.configure(uploader, storages: nil)
        uploader.opts[:moving_storages] = storages
      end

      module InstanceMethods
        private

        # If the storage supports moving we use that, otherwise we do moving by
        # copying and deleting.
        def copy(io, context)
          if move?(io, context)
            move(io, context)
          else
            super
          end
        end

        def move(io, context)
          storage.move(io, context[:location], context[:metadata])
        end

        def movable?(io, context)
          storage.respond_to?(:move) && storage.movable?(io, context[:location])
        end

        def move?(io, context)
          moving_storage? && movable?(io, context)
        end

        def moving_storage?
          opts[:moving_storages].nil? ||
          opts[:moving_storages].include?(storage_key)
        end
      end
    end

    register_plugin(:moving, Moving)
  end
end
