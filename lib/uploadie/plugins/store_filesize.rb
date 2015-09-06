class Uploadie
  module Plugins
    module StoreFilesize
      module InstanceMethods
        def extract_metadata(io)
          metadata = super
          metadata["size"] = extract_size(io)
          metadata
        end

        private

        def extract_size(io)
          io.size
        end
      end

      module FileMethods
        def size
          metadata.fetch("size")
        end
      end
    end

    register_plugin(:store_filesize, StoreFilesize)
  end
end
