class Uploadie
  module Plugins
    module ExtractContentType
      SUPPORTED_LIBRARIES = [:mime_types, :filemagic]

      def self.configure(uploadie, library:)
        raise Error, "unsupported content type library: #{library.inspect}" if !SUPPORTED_LIBRARIES.include?(library)
        uploadie.opts[:content_type_library] = library
      end

      module InstanceMethods
        def extract_content_type(io)
          send(:"_extract_#{opts[:content_type_library]}_content_type", io)
        end

        private

        def _extract_mime_types_content_type(io)
          if filename = extract_filename(io)
            content_type = MIME::Types.of(filename).first
            content_type.to_s if content_type
          end
        end

        def _extract_filemagic_content_type(io)
          filemagic = FileMagic.new(FileMagic::MAGIC_MIME_TYPE)
          data = io.read(1024); io.rewind
          filemagic.buffer(data)
        end
      end
    end

    register_plugin(:extract_content_type, ExtractContentType)
  end
end
