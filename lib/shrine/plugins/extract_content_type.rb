class Shrine
  module Plugins
    module ExtractContentType
      def self.load_dependencies(uploader, extractor:)
        case extractor
        when :mime_types
          begin
            require "mime/types/columnar"
          rescue LoadError
            require "mime/types"
          end
        when :filemagic
          require "filemagic"
        when :file
          require "shellwords"
        end
      end

      def self.configure(uploader, extractor:)
        uploader.opts[:content_type_extractor] = extractor
      end

      module InstanceMethods
        def extract_content_type(io)
          extractor = opts[:content_type_extractor]

          if content_type = super
            content_type
          elsif extractor.is_a?(Symbol)
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

        def _extract_content_type_with_file(io)
          if io.respond_to?(:path)
            content_type = `file -b --mime-type #{io.path.shellescape}`
            content_type.strip unless content_type.empty?
          end
        end
      end
    end

    register_plugin(:extract_content_type, ExtractContentType)
  end
end
