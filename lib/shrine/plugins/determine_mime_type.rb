class Shrine
  module Plugins
    # The determine_mime_type plugin stores the actual MIME type of the
    # uploaded file.
    #
    #     plugin :determine_mime_type
    #
    # By default the UNIX [file] utility is used to determine the MIME type, but
    # you can change it:
    #
    #     plugin :determine_mime_type, analyzer: :filemagic
    #
    # The plugin accepts the following analyzers:
    #
    # :file
    # : (Default). Uses the [file] utility to determine the MIME type from file
    #   contents. It is installed by default on most operating systems, but the
    #   [Windows equivalent] you need to install separately.
    #
    # :filemagic
    # : Uses the [ruby-filemagic] gem to determine the MIME type from file
    #   contents, using a similar MIME database as the `file` utility.
    #   Unlike the `file` utility, ruby-filemagic should work on Windows.
    #
    # :mimemagic
    # : Uses the [mimemagic] gem to determine the MIME type from file contents.
    #   Unlike ruby-filemagic, mimemagic is a pure-ruby solution, so it will
    #   work across all Ruby implementations.
    #
    # :mime_types
    # : Uses the [mime-types] gem to determine the MIME type from the file
    #   *extension*. Note that unlike other solutions, this analyzer is not
    #   guaranteed to return the actual MIME type of the file.
    #
    # If none of these quite suit your needs, you can use a custom analyzer:
    #
    #     plugin :determine_mime_type, analyzer: ->(io) do
    #       # returns the extracted MIME type
    #     end
    #
    # [file]: http://linux.die.net/man/1/file
    # [Windows equivalent]: http://gnuwin32.sourceforge.net/packages/file.htm
    # [ruby-filemagic]: https://github.com/blackwinter/ruby-filemagic
    # [mimemagic]: https://github.com/minad/mimemagic
    # [mime-types]: https://github.com/mime-types/ruby-mime-types
    module DetermineMimeType
      def self.load_dependencies(uploader, analyzer: :file)
        case analyzer
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

      def self.configure(uploader, analyzer: :file)
        uploader.opts[:mime_type_analyzer] = analyzer
      end

      # How many bytes we have to read to get the magic file header which
      # contains the MIME type of the file.
      MAGIC_NUMBER = 1024

      module InstanceMethods
        # If a Shrine::UploadedFile was given, it returns its MIME type, since
        # that value was already determined by this analyzer. Otherwise it calls
        # a built-in analyzer or a custom one.
        def extract_mime_type(io)
          analyzer = opts[:mime_type_analyzer]

          if io.respond_to?(:mime_type)
            io.mime_type
          elsif analyzer.is_a?(Symbol)
            send(:"_extract_mime_type_with_#{analyzer}", io)
          else
            analyzer.call(io)
          end
        end

        private

        # Uses the UNIX file utility to extract the MIME type. It does so only
        # if it's a file, because even though the utility accepts standard
        # input, it would mean that we have to read the whole file in memory.
        def _extract_mime_type_with_file(io)
          cmd = ["file", "--mime-type", "--brief"]

          if io.respond_to?(:path)
            mime_type, _ = Open3.capture2(*cmd, io.path)
          else
            mime_type, _ = Open3.capture2(*cmd, "-", stdin_data: io.read(MAGIC_NUMBER), binmode: true)
            io.rewind
          end

          mime_type.strip unless mime_type.empty?
        end

        # Uses the ruby-filemagic gem to magically extract the MIME type.
        def _extract_mime_type_with_filemagic(io)
          filemagic = FileMagic.new(FileMagic::MAGIC_MIME_TYPE)
          data = io.read(MAGIC_NUMBER)
          io.rewind
          filemagic.buffer(data)
        end

        # Uses the mimemagic gem to extract the MIME type.
        def _extract_mime_type_with_mimemagic(io)
          result = MimeMagic.by_magic(io).type
          io.rewind
          result
        end

        # Uses the mime-types gem to determine MIME type from file extension.
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
