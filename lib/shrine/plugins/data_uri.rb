# frozen_string_literal: true

require "base64"
require "strscan"
require "cgi"
require "stringio"

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/data_uri
    module DataUri
      class ParseError < Error; end

      DATA_REGEXP          = /data:/
      MEDIA_TYPE_REGEXP    = /[-\w.+]+\/[-\w.+]+(;[-\w.+]+=[^;,]+)*/
      BASE64_REGEXP        = /;base64/
      CONTENT_SEPARATOR    = /,/
      DEFAULT_CONTENT_TYPE = "text/plain"

      LOG_SUBSCRIBER = -> (event) do
        Shrine.logger.info "Data URI (#{event.duration}ms) – #{{
          uploader: event[:uploader],
        }.inspect}"
      end

      def self.load_dependencies(uploader, *)
        uploader.plugin :validation
      end

      def self.configure(uploader, log_subscriber: LOG_SUBSCRIBER, **opts)
        uploader.opts[:data_uri] ||= {}
        uploader.opts[:data_uri].merge!(opts)

        # instrumentation plugin integration
        uploader.subscribe(:data_uri, &log_subscriber) if uploader.respond_to?(:subscribe)
      end

      module AttachmentMethods
        def define_model_methods(name)
          super if defined?(super)

          define_method :"#{name}_data_uri=" do |uri|
            send(:"#{name}_attacher").data_uri = uri
          end

          define_method :"#{name}_data_uri" do
            send(:"#{name}_attacher").data_uri
          end
        end
      end

      module ClassMethods
        # Parses the given data URI and creates an IO object from it.
        #
        #     io = Shrine.data_uri("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA")
        #     io #=> #<Shrine::Plugins::DataUri::DataFile>
        #     io.content_type #=> "image/png"
        #     io.size         #=> 21
        #     io.read         # decoded content
        def data_uri(uri, filename: nil)
          instrument_data_uri(uri) do
            info = parse_data_uri(uri)
            create_data_file(info, filename: filename)
          end
        end

        private

        # Creates an IO-like object from parsed data URI.
        def create_data_file(info, filename: nil)
          content_type = info[:content_type] || DEFAULT_CONTENT_TYPE
          content      = info[:base64] ? Base64.decode64(info[:data]) : CGI.unescape(info[:data])

          data_file = Shrine::DataFile.new(content, content_type: content_type, filename: filename)
          info[:data].clear

          data_file
        end

        # Parses the data URI string and returns parts.
        def parse_data_uri(uri)
          scanner = StringScanner.new(uri)
          scanner.scan(DATA_REGEXP) or raise ParseError, "data URI has invalid format"
          media_type = scanner.scan(MEDIA_TYPE_REGEXP)
          base64 = scanner.scan(BASE64_REGEXP)
          scanner.scan(CONTENT_SEPARATOR) or raise ParseError, "data URI has invalid format"
          content = scanner.post_match

          { content_type: media_type, base64: !!base64, data: content }
        end

        # Sends a `data_uri.shrine` event for instrumentation plugin.
        def instrument_data_uri(uri, &block)
          return yield unless respond_to?(:instrument)

          instrument(:data_uri, data_uri: uri, &block)
        end
      end

      module AttacherMethods
        # Handles assignment of a data URI. If the regexp matches, it extracts
        # the content type, decodes it, wrappes it in a StringIO and assigns it.
        # If it fails, it sets the error message and assigns the uri in an
        # instance variable so that it shows up on the UI.
        def assign_data_uri(uri, **options)
          return if uri == "" || uri.nil?

          data_file = shrine_class.data_uri(uri)
          attach_cached(data_file, **options)
        rescue ParseError => error
          errors.clear << data_uri_error_messsage(uri, error)
          false
        end

        # Used by `<name>_data_uri=` attachment method.
        def data_uri=(uri)
          assign_data_uri(uri)
          @data_uri = uri
        end

        # Used by `<name>_data_uri` attachment method.
        def data_uri
          @data_uri
        end

        private

        # Generates an error message for failed data URI parse.
        def data_uri_error_messsage(uri, error)
          message = shrine_class.opts[:data_uri][:error_message]
          message = message.call(uri) if message.respond_to?(:call)
          message || error.message
        end
      end

      module FileMethods
        # Returns the data URI representation of the file.
        def data_uri
          @data_uri ||= "data:#{mime_type || "text/plain"};base64,#{base64}"
        end

        # Returns contents of the file base64-encoded.
        def base64
          binary = open { |io| io.read }
          result = Base64.strict_encode64(binary)
          binary.clear # deallocate string
          result
        end
      end
    end

    register_plugin(:data_uri, DataUri)
  end
end
