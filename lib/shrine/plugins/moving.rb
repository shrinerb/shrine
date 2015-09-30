class Shrine
  module Plugins
    module Moving
      def self.configure(uploader, storages:)
        uploader.opts[:move_files_to_storages] = storages
      end

      module InstanceMethods
        private

        def put(io, context)
          if move?(io, context)
            if movable?(io, context)
              move(io, context[:location])
            else
              super
              io.delete if io.respond_to?(:delete)
            end
          else
            super
          end
        end

        def movable?(io, context)
          storage.respond_to?(:move) && storage.movable?(io, context[:location])
        end

        def move?(io, context)
          opts[:move_files_to_storages].include?(storage_key)
        end
      end
    end

    register_plugin(:moving, Moving)
  end
end
