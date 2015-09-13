class Uploadie
  module Plugins
    module ExtractContentType
      def self.load_dependencies(uploadie, extractor:)
        case extractor
        when :mime_types
          begin
            require "mime/types/columnar"
          rescue LoadError
            require "mime/types"
          end
        when :filemagic
          require "filemagic"
        end
      end

      def self.configure(uploadie, extractor:)
        uploadie.opts[:content_type_extractor] = extractor
      end

      module InstanceMethods
        def extract_content_type(io)
          extractor = opts[:content_type_extractor]

          if extractor.is_a?(Symbol)
            send(:"_extract_content_type_with_#{extractor}", io)
          else
            extractor.call(io)
          end
        end

        private

        def _extract_content_type_with_mime_types(io)
          if filename = extract_filename(io)
            content_type = MIME::Types.of(filename).first
            content_type.to_s if content_type
          end
        end

        def _extract_content_type_with_filemagic(io)
          filemagic = FileMagic.new(FileMagic::MAGIC_MIME_TYPE)
          data = io.read(1024); io.rewind
          filemagic.buffer(data)
        end
      end
    end

    register_plugin(:extract_content_type, ExtractContentType)
  end
end
