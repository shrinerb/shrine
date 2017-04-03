class Shrine
  module Plugins
    # The `determine_mime_type` plugin allows you to determine and store the
    # actual MIME type of the file analyzed from file content.
    #
    #     plugin :determine_mime_type
    #
    # By default the UNIX [file] utility is used to determine the MIME type,
    # and the result is automatically written to the `mime_type` metadata
    # field. You can choose a different built-in MIME type analyzer:
    #
    #     plugin :determine_mime_type, analyzer: :filemagic
    #
    # The following analyzers are accepted:
    #
    # :file
    # : (Default). Uses the [file] utility to determine the MIME type from file
    #   contents. It is installed by default on most operating systems, but the
    #   [Windows equivalent] needs to be installed separately.
    #
    # :filemagic
    # : Uses the [ruby-filemagic] gem to determine the MIME type from file
    #   contents, using a similar MIME database as the `file` utility. Unlike
    #   the `file` utility, ruby-filemagic works on Windows without any setup.
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
    # :default
    # : Uses the default way of extracting the MIME type, and that is reading
    #   the `#content_type` attribute of the IO object, which might not hold
    #   the actual MIME type of the file.
    #
    # A single analyzer is not going to properly recognize all types of files,
    # so you can build your own custom analyzer for your requirements, where
    # you can combine the built-in analyzers. For example, if you want to
    # correctly determine MIME type of .css, .js, .json, .csv, .xml, or similar
    # text-based files, you can combine `file` and `mime_types` analyzers:
    #
    #     plugin :determine_mime_type, analyzer: ->(io, analyzers) do
    #       mime_type = analyzers[:file].call(io)
    #       mime_type = analyzers[:mime_types].call(io) if mime_type == "text/plain"
    #       mime_type
    #     end
    #
    # You can also use methods for determining the MIME type directly:
    #
    #     Shrine.determine_mime_type(io) # calls the defined analyzer
    #     #=> "image/jpeg"
    #
    #     Shrine.mime_type_analyzers[:file].call(io) # calls a built-in analyzer
    #     #=> "image/jpeg"
    #
    # [file]: http://linux.die.net/man/1/file
    # [Windows equivalent]: http://gnuwin32.sourceforge.net/packages/file.htm
    # [ruby-filemagic]: https://github.com/blackwinter/ruby-filemagic
    # [mimemagic]: https://github.com/minad/mimemagic
    # [mime-types]: https://github.com/mime-types/ruby-mime-types
    module DetermineMimeType
      def self.configure(uploader, opts = {})
        uploader.opts[:mime_type_analyzer] = opts.fetch(:analyzer, uploader.opts.fetch(:mime_type_analyzer, :file))
      end

      module ClassMethods
        def determine_mime_type(io)
          analyzer = opts[:mime_type_analyzer]
          analyzer = mime_type_analyzers[analyzer] if analyzer.is_a?(Symbol)
          args     = [io, mime_type_analyzers].take(analyzer.arity.abs)

          mime_type = analyzer.call(*args)
          io.rewind

          mime_type
        end

        def mime_type_analyzers
          @mime_type_analyzers ||= MimeTypeAnalyzer::SUPPORTED_TOOLS.inject({}) do |hash, tool|
            hash.merge!(tool => MimeTypeAnalyzer.new(tool).method(:call))
          end
        end
      end

      module InstanceMethods
        private

        # If a Shrine::UploadedFile was given, it returns its MIME type, since
        # that value was already determined by this analyzer. Otherwise it calls
        # a built-in analyzer or a custom one.
        def extract_mime_type(io)
          if opts[:mime_type_analyzer] == :default
            super
          else
            self.class.determine_mime_type(io)
          end
        end

        def mime_type_analyzers
          self.class.mime_type_analyzers
        end
      end

      class MimeTypeAnalyzer
        SUPPORTED_TOOLS = [:file, :filemagic, :mimemagic, :mime_types]
        MAGIC_NUMBER    = 256 * 1024

        def initialize(tool)
          raise ArgumentError, "unsupported mime type analyzer tool: #{tool}" unless SUPPORTED_TOOLS.include?(tool)

          @tool = tool
        end

        def call(io)
          mime_type = send(:"extract_with_#{@tool}", io)
          io.rewind
          mime_type
        end

        private

        def extract_with_file(io)
          require "open3"

          cmd = ["file", "--mime-type", "--brief", "-"]
          options = {stdin_data: io.read(MAGIC_NUMBER), binmode: true}

          begin
            stdout, stderr, status = Open3.capture3(*cmd, options)
          rescue Errno::ENOENT
            raise Error, "The `file` command-line tool is not installed"
          end

          raise Error, stderr unless status.success?
          $stderr.print(stderr)

          stdout.strip
        end

        def extract_with_filemagic(io)
          require "filemagic"

          filemagic = FileMagic.new(FileMagic::MAGIC_MIME_TYPE)
          mime_type = filemagic.buffer(io.read(MAGIC_NUMBER))
          filemagic.close

          mime_type
        end

        def extract_with_mimemagic(io)
          require "mimemagic"

          mime = MimeMagic.by_magic(io)
          mime.type if mime
        end

        def extract_with_mime_types(io)
          begin
            require "mime/types/columnar"
          rescue LoadError
            require "mime/types"
          end

          if filename = extract_filename(io)
            mime_type = MIME::Types.of(filename).first
            mime_type.to_s if mime_type
          end
        end

        def extract_filename(io)
          if io.respond_to?(:original_filename)
            io.original_filename
          elsif io.respond_to?(:path)
            File.basename(io.path)
          end
        end
      end

    end

    register_plugin(:determine_mime_type, DetermineMimeType)
  end
end
