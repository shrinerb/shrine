class Uploadie
  module Plugins
    module StoreFilesize
      module InstanceMethods
        def uploaded_file(io, location)
          uploaded_file = super
          uploaded_file.metadata["size"] = extract_size(io)
          uploaded_file
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
