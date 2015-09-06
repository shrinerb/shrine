class Uploadie
  module Plugins
    module StoreContentType
      module InstanceMethods
        def extract_metadata(io)
          metadata = super
          metadata["content_type"] = extract_content_type(io)
          metadata
        end

        private

        def extract_content_type(io)
          if io.respond_to?(:content_type)
            io.content_type
          elsif filename = extract_filename(io)
            if defined?(MIME::Types)
              content_type = MIME::Types.of(filename).first
              content_type.to_s if content_type
            end
          end
        end
      end

      module FileMethods
        def content_type
          metadata.fetch("content_type")
        end
      end
    end

    register_plugin(:store_content_type, StoreContentType)
  end
end
