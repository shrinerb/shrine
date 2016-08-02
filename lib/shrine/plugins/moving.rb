class Shrine
  module Plugins
    # The moving plugin will *move* files to storages instead of copying them,
    # when the storage supports it. For FileSystem this will issue a `mv`
    # command, which is instantaneous regardless of the filesize, so in that
    # case loading this plugin can significantly speed up the attachment
    # process.
    #
    #     plugin :moving
    #
    # By default files will be moved whenever the storage supports it. If you
    # want moving to happen only for certain storages, you can set `:storages`:
    #
    #     plugin :moving, storages: [:cache]
    module Moving
      def self.configure(uploader, opts = {})
        uploader.opts[:moving_storages] = opts.fetch(:storages, uploader.opts[:moving_storages])
      end

      module InstanceMethods
        private

        # Moves the file if storage supports it, otherwise defaults to copying.
        def copy(io, context)
          if move?(io, context)
            move(io, context)
          else
            super
          end
        end

        # Generates upload options and calls `#move` on the storage.
        def move(io, context)
          location = context[:location]
          metadata = context[:metadata]
          upload_options = context[:upload_options] || {}

          storage.move(io, location, shrine_metadata: metadata, **upload_options)
        end

        # Returns true if file should be moved and is movable.
        def move?(io, context)
          moving_storage? && movable?(io, context)
        end

        # Returns true if storage can move this file.
        def movable?(io, context)
          storage.respond_to?(:move) && storage.movable?(io, context[:location])
        end

        # Returns true if file should be moved.
        def moving_storage?
          opts[:moving_storages].nil? ||
          opts[:moving_storages].include?(storage_key)
        end
      end
    end

    register_plugin(:moving, Moving)
  end
end
