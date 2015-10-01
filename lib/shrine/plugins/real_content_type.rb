class Shrine
  module Plugins
    module RealContentType
      def self.load_dependencies(uploader, extractor: :file)
        case extractor
        when :file      then require "open3"
        when :filemagic then require "filemagic"
        when :mimemagic then require "mimemagic"
        end
      end

      def self.configure(uploader, extractor: :file)
        uploader.opts[:content_type_extractor] = extractor
      end

      module InstanceMethods
        def extract_content_type(io)
          extractor = opts[:content_type_extractor]

          if io.is_a?(UploadedFile)
            io.content_type
          elsif extractor.is_a?(Symbol)
            send(:"_extract_content_type_with_#{extractor}", io)
          else
            extractor.call(io)
          end
        end

        private

        def _extract_content_type_with_file(io)
          if io.respond_to?(:path)
            content_type, _ = Open3.capture2("file", "-b", "--mime-type", io.path)
            content_type.strip unless content_type.empty?
          end
        end

        def _extract_content_type_with_filemagic(io)
          filemagic = FileMagic.new(FileMagic::MAGIC_MIME_TYPE)
          data = io.read(1024); io.rewind
          filemagic.buffer(data)
        end

        def _extract_content_type_with_mimemagic(io)
          MimeMagic.by_magic(io).type
        end
      end
    end

    register_plugin(:real_content_type, RealContentType)
  end
end
