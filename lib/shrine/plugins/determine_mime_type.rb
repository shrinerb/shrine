class Shrine
  module Plugins
    # The determine_mime_type gives you the ability to determine (and save) the
    # actual MIME type of the file being uploaded.
    #
    #     plugin :determine_mime_type
    #
    # The plugin accepts the following analysers:
    #
    # :file
    # : (Default). Uses the UNIX [file] utility to determine the MIME type
    #   from file contents.
    #
    # :filemagic
    # : Uses the [ruby-filemagic] gem to determine the MIME type from file
    #   contents, using a similar MIME database as the `file` utility. However,
    #   unlike the `file` utility, ruby-filemagic should work on Windows.
    #
    # :mimemagic
    # : Uses the [mimemagic] gem to determine the MIME type from file contents.
    #   Unlike ruby-filemagic, mimemagic is a pure-ruby solution, so it will
    #   work on all Ruby implementations.
    #
    # :mime_types
    # : Uses the [mime-types] gem to determine the MIME type from the file
    #   extension. Unlike other solutions, this is not guaranteed to return
    #   the actual MIME type, since the attacker can just upload a video with
    #   the .jpg extension.
    #
    # By default the UNIX [file] utility is used to detrmine the MIME type, but
    # you can change it:
    #
    #     plugin :determine_mime_type, analyser: :filemagic
    #
    # If none of these quite suit your needs, you can use a custom analyser:
    #
    #     plugin :determine_mime_type, analyser: ->(io) do
    #       if io.path.end_with?(".odt")
    #         "application/vnd.oasis.opendocument.text"
    #       else
    #         MimeMagic.by_magic(io).type
    #       end
    #     end
    #
    # [file]: http://linux.die.net/man/1/file
    # [ruby-filemagic]: https://github.com/blackwinter/ruby-filemagic
    # [mimemagic]: https://github.com/minad/mimemagic
    # [mime-types]: https://github.com/mime-types/ruby-mime-types
    module DetermineMimeType
      def self.load_dependencies(uploader, analyser: :file)
        case analyser
        when :file      then require "open3"
        when :filemagic then require "filemagic"
        when :mimemagic then require "mimemagic"
        when :mime_types
          begin
            require "mime/types/columnar"
          rescue LoadError
            require "mime/types"
          end
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

        def _extract_mime_type_with_mime_types(io)
          if filename = extract_filename(io)
            mime_type = MIME::Types.of(filename).first
            mime_type.to_s if mime_type
          end
        end
      end
    end

    register_plugin(:determine_mime_type, DetermineMimeType)
  end
end
