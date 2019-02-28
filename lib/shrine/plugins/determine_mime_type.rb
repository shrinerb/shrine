# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/determine_mime_type.md] on GitHub.
    #
    # [doc/plugins/determine_mime_type.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/determine_mime_type.md
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

          Marcel::MimeType.for(io)
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
