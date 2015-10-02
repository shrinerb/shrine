class Shrine
  module Plugins
    module DetermineMimeType
      def self.load_dependencies(uploader, analyser: :file)
        case analyser
        when :file      then require "open3"
        when :filemagic then require "filemagic"
        when :mimemagic then require "mimemagic"
        end
      end

      def self.configure(uploader, analyser: :file)
        uploader.opts[:mime_type_analyser] = analyser
      end

      module InstanceMethods
        def extract_mime_type(io)
          analyser = opts[:mime_type_analyser]

          if io.respond_to?(:mime_type)
            io.mime_type
          elsif analyser.is_a?(Symbol)
            send(:"_extract_mime_type_with_#{analyser}", io)
          else
            analyser.call(io)
          end
        end

        private

        def _extract_mime_type_with_file(io)
          if io.respond_to?(:path)
            mime_type, _ = Open3.capture2("file", "-b", "--mime-type", io.path)
            mime_type.strip unless mime_type.empty?
          end
        end

        def _extract_mime_type_with_filemagic(io)
          filemagic = FileMagic.new(FileMagic::MAGIC_MIME_TYPE)
          data = io.read(1024); io.rewind
          filemagic.buffer(data)
        end

        def _extract_mime_type_with_mimemagic(io)
          MimeMagic.by_magic(io).type
        end
      end
    end

    register_plugin(:determine_mime_type, DetermineMimeType)
  end
end
