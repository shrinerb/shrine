# frozen_string_literal: true

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
    #     plugin :determine_mime_type, analyzer: :marcel
    #
    # The following analyzers are accepted:
    #
    # :file
    # : (Default). Uses the [file] utility to determine the MIME type from file
    #   contents. It is installed by default on most operating systems, but the
    #   [Windows equivalent] needs to be installed separately.
    #
    # :fastimage
    # : Uses the [fastimage] gem to determine the MIME type from file contents.
    #   Fastimage is optimized for speed over accuracy. Best used for image content.
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
    # :marcel
    # : Uses the [marcel] gem to determine the MIME type from file contents.
    #   Marcel is Basecamp's wrapper around mimemagic, it adds priority logic
    #   (preferring magic over name when given both), some extra type
    #   definitions, and common type subclasses (including Keynote, Pages,
    #   etc).
    #
    # :mime_types
    # : Uses the [mime-types] gem to determine the MIME type from the file
    #   extension. Note that unlike other solutions, this analyzer is not
    #   guaranteed to return the actual MIME type of the file.
    #
    # :mini_mime
    # : Uses the [mini_mime] gem to determine the MIME type from the file
    #   extension. Note that unlike other solutions, this analyzer is not
    #   guaranteed to return the actual MIME type of the file.
    #
    # :content_type
    # : Retrieves the value of the `#content_type` attribute of the IO object.
    #   Note that this value normally comes from the "Content-Type" request
    #   header, so it's not guaranteed to hold the actual MIME type of the file.
    #
    # A single analyzer is not going to properly recognize all types of files,
    # so you can build your own custom analyzer for your requirements, where
    # you can combine the built-in analyzers. For example, if you want to
    # correctly determine MIME type of .css, .js, .json, .csv, .xml, or similar
    # text-based files, you can combine `file` and `mime_types` analyzers:
    #
    #     plugin :determine_mime_type, analyzer: -> (io, analyzers) do
    #       mime_type = analyzers[:file].call(io)
    #       mime_type = analyzers[:mime_types].call(io) if mime_type == "text/plain"
    #       mime_type
    #     end
    #
    # You can also use methods for determining the MIME type directly:
    #
    #     # or YourUploader.determine_mime_type(io)
    #     Shrine.determine_mime_type(io) # calls the defined analyzer
    #     #=> "image/jpeg"
    #
    #     # or YourUploader.mime_type_analyzers
    #     Shrine.mime_type_analyzers[:file].call(io) # calls a built-in analyzer
    #     #=> "image/jpeg"
    #
    # [file]: http://linux.die.net/man/1/file
    # [Windows equivalent]: http://gnuwin32.sourceforge.net/packages/file.htm
    # [ruby-filemagic]: https://github.com/blackwinter/ruby-filemagic
    # [mimemagic]: https://github.com/minad/mimemagic
    # [marcel]: https://github.com/basecamp/marcel
    # [mime-types]: https://github.com/mime-types/ruby-mime-types
    # [mini_mime]: https://github.com/discourse/mini_mime
    # [fastimage]: https://github.com/sdsykes/fastimage
    module DetermineMimeType
      def self.configure(uploader, opts = {})
        if opts[:analyzer] == :default
          Shrine.deprecation("The :default analyzer of the determine_mime_type plugin has been renamed to :content_type. The :default alias will not be supported in Shrine 3.")
          opts = opts.merge(analyzer: :content_type)
        end

        uploader.opts[:mime_type_analyzer] = opts.fetch(:analyzer, uploader.opts.fetch(:mime_type_analyzer, :file))
      end

      module ClassMethods
        # Determines the MIME type of the IO object by calling the specified
        # analyzer.
        def determine_mime_type(io)
          analyzer = opts[:mime_type_analyzer]
          analyzer = mime_type_analyzer(analyzer) if analyzer.is_a?(Symbol)
          args     = [io, mime_type_analyzers].take(analyzer.arity.abs)

          mime_type = analyzer.call(*args)
          io.rewind

          mime_type
        end

        # Returns a hash of built-in MIME type analyzers, where keys are
        # analyzer names and values are `#call`-able objects which accepts the
        # IO object.
        def mime_type_analyzers
          @mime_type_analyzers ||= MimeTypeAnalyzer::SUPPORTED_TOOLS.inject({}) do |hash, tool|
            hash.merge!(tool => mime_type_analyzer(tool))
          end
        end

        # Returns callable mime type analyzer object.
        def mime_type_analyzer(name)
          MimeTypeAnalyzer.new(name).method(:call)
        end
      end

      module InstanceMethods
        private

        # Calls the configured MIME type analyzer.
        def extract_mime_type(io)
          self.class.determine_mime_type(io)
        end

        # Returns a hash of built-in MIME type analyzers.
        def mime_type_analyzers
          self.class.mime_type_analyzers
        end
      end

      class MimeTypeAnalyzer
        SUPPORTED_TOOLS = [:fastimage, :file, :filemagic, :mimemagic, :marcel, :mime_types, :mini_mime, :content_type]
        MAGIC_NUMBER    = 256 * 1024

        def initialize(tool)
          raise Error, "unknown mime type analyzer #{tool.inspect}, supported analyzers are: #{SUPPORTED_TOOLS.join(",")}" unless SUPPORTED_TOOLS.include?(tool)

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

          return nil if io.eof? # file command returns "application/x-empty" for empty files

          Open3.popen3(*%W[file --mime-type --brief -]) do |stdin, stdout, stderr, thread|
            begin
              IO.copy_stream(io, stdin.binmode)
            rescue Errno::EPIPE
            end
            stdin.close

            status = thread.value

            raise Error, "file command failed to spawn: #{stderr.read}" if status.nil?
            raise Error, "file command failed: #{stderr.read}" unless status.success?

            $stderr.print(stderr.read)

            output = stdout.read.strip

            raise Error, "file command failed: #{output}" if output.include?("cannot open")

            output
          end
        rescue Errno::ENOENT
          raise Error, "file command-line tool is not installed"
        end

        def extract_with_fastimage(io)
          require "fastimage"

          type = FastImage.type(io)
          "image/#{type}" if type
        end

        def extract_with_filemagic(io)
          require "filemagic"

          return nil if io.eof? # FileMagic returns "application/x-empty" for empty files

          FileMagic.open(FileMagic::MAGIC_MIME_TYPE) do |filemagic|
            filemagic.buffer(io.read(MAGIC_NUMBER))
          end
        end

        def extract_with_mimemagic(io)
          require "mimemagic"

          mime = MimeMagic.by_magic(io)
          mime.type if mime
        end

        def extract_with_marcel(io)
          require "marcel"

          return nil if io.eof? # marcel returns "application/octet-stream" for empty files

          Marcel::MimeType.for(io, name: extract_filename(io))
        end

        def extract_with_mime_types(io)
          require "mime/types"

          if filename = extract_filename(io)
            mime_type = MIME::Types.of(filename).first
            mime_type.content_type if mime_type
          end
        end

        def extract_with_mini_mime(io)
          require "mini_mime"

          if filename = extract_filename(io)
            info = MiniMime.lookup_by_filename(filename)
            info.content_type if info
          end
        end

        def extract_with_content_type(io)
          if io.respond_to?(:content_type) && io.content_type
            io.content_type.split(";").first
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
