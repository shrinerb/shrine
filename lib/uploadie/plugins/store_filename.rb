class Uploadie
  module Plugins
    module StoreFilename
      module InstanceMethods
        def upload(io, *)
          uploaded_file = super
          uploaded_file.metadata["original_filename"] = extract_filename(io)
          uploaded_file
        end
      end

      module FileMethods
        def original_filename
          metadata.fetch("original_filename")
        end

        def extension
          File.extname(original_filename) if original_filename
        end
      end
    end

    register_plugin(:store_filename, StoreFilename)
  end
end
