begin
  require "mime/types/columnar"
rescue LoadError
  require "mime/types"
end

class Uploadie
  module Plugins
    module MimeTypes
      module InstanceMethods
        def extract_content_type(io)
          if filename = extract_filename(io)
            content_type = MIME::Types.of(filename).first
            content_type.to_s if content_type
          end
        end
      end
    end

    register_plugin(:mime_types, MimeTypes)
  end
end
