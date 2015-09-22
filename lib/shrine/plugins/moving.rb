class Shrine
  module Plugins
    module Moving
      def self.configure(uploader, storages:)
        uploader.opts[:move_files_to_storages] = storages
      end

      module InstanceMethods
        private

        def store(io, location)
          if move_file?
            if storage.respond_to?(:move) && storage.movable?(io, location)
              storage.move(io, location)
            else
              super
              io.delete if io.respond_to?(:delete)
            end
          else
            super
          end
        end

        def move_file?
          opts[:move_files_to_storages].include?(storage_key)
        end
      end
    end

    register_plugin(:moving, Moving)
  end
end
