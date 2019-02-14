# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/moving.md] on GitHub.
    #
    # [doc/plugins/moving.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/moving.md
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
          return false if context[:move] == false
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
