# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/determine_mime_type
    module DetermineMimeType
      LOG_SUBSCRIBER = -> (event) do
        Shrine.logger.info "MIME Type (#{event.duration}ms) – #{{
          io:       event[:io].class,
          uploader: event[:uploader],
        }.inspect}"
      end

      def self.configure(uploader, log_subscriber: LOG_SUBSCRIBER, **opts)
        uploader.opts[:determine_mime_type] ||= { analyzer: :file, analyzer_options: {} }
        uploader.opts[:determine_mime_type].merge!(opts)

        # instrumentation plugin integration
        uploader.subscribe(:mime_type, &log_subscriber) if uploader.respond_to?(:subscribe)
      end

      module ClassMethods
        # Determines the MIME type of the IO object by calling the specified
        # analyzer.
        def determine_mime_type(io)
          analyzer = opts[:determine_mime_type][:analyzer]

          analyzer = mime_type_analyzer(analyzer) if analyzer.is_a?(Symbol)
          args     = if analyzer.is_a?(Proc)
              [io, mime_type_analyzers].take(analyzer.arity.abs)
            else
              [io, opts[:determine_mime_type][:analyzer_options]]
            end

          mime_type = instrument_mime_type(io) { analyzer.call(*args) }
          io.rewind

          mime_type
        end
        alias mime_type determine_mime_type

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
          MimeTypeAnalyzer.new(name)
        end

        private

        # Sends a `mime_type.shrine` event for instrumentation plugin.
        def instrument_mime_type(io, &block)
          return yield unless respond_to?(:instrument)

          instrument(:mime_type, io: io, &block)
        end
      end

      module InstanceMethods
        private

        # Calls the configured MIME type analyzer.
        def extract_mime_type(io)
          self.class.determine_mime_type(io)
        end
      end

      class MimeTypeAnalyzer
        SUPPORTED_TOOLS = [:fastimage, :file, :filemagic, :mimemagic, :marcel, :mime_types, :mini_mime, :content_type]
        MAGIC_NUMBER    = 256 * 1024

        def initialize(tool)
          raise Error, "unknown mime type analyzer #{tool.inspect}, supported analyzers are: #{SUPPORTED_TOOLS.join(",")}" unless SUPPORTED_TOOLS.include?(tool)

          @tool = tool
        end

        def call(io, options = {})
          mime_type = send(:"extract_with_#{@tool}", io, options)
          io.rewind

          mime_type
        end

        private

        def extract_with_file(io, options)
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

        def extract_with_fastimage(io, options)
          require "fastimage"

          type = FastImage.type(io)
          "image/#{type}" if type
        end

        def extract_with_filemagic(io, options)
          require "filemagic"

          return nil if io.eof? # FileMagic returns "application/x-empty" for empty files

          FileMagic.open(FileMagic::MAGIC_MIME_TYPE) do |filemagic|
            filemagic.buffer(io.read(MAGIC_NUMBER))
          end
        end

        def extract_with_mimemagic(io, options)
          require "mimemagic"

          mime = MimeMagic.by_magic(io)
          mime.type if mime
        end

        def extract_with_marcel(io, options)
          require "marcel"

          return nil if io.eof? # marcel returns "application/octet-stream" for empty files

          filename = (options[:filename_fallback] ? extract_filename(io) : nil)
          Marcel::MimeType.for(io, name: filename)
        end

        def extract_with_mime_types(io, options)
          require "mime/types"

          if filename = extract_filename(io)
            mime_type = MIME::Types.of(filename).first
            mime_type.content_type if mime_type
          end
        end

        def extract_with_mini_mime(io, options)
          require "mini_mime"

          if filename = extract_filename(io)
            info = MiniMime.lookup_by_filename(filename)
            info.content_type if info
          end
        end

        def extract_with_content_type(io, options)
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
