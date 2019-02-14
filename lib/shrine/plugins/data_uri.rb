# frozen_string_literal: true

require "base64"
require "strscan"
require "cgi"
require "stringio"
require "forwardable"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/data_uri.md] on GitHub.
    #
    # [doc/plugins/data_uri.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/data_uri.md
    module DataUri
      class ParseError < Error; end

      DATA_REGEXP          = /data:/
      MEDIA_TYPE_REGEXP    = /[-\w.+]+\/[-\w.+]+(;[-\w.+]+=[^;,]+)*/
      BASE64_REGEXP        = /;base64/
      CONTENT_SEPARATOR    = /,/
      DEFAULT_CONTENT_TYPE = "text/plain"

      def self.configure(uploader, opts = {})
        uploader.opts[:data_uri_filename] = opts.fetch(:filename, uploader.opts[:data_uri_filename])
        uploader.opts[:data_uri_error_message] = opts.fetch(:error_message, uploader.opts[:data_uri_error_message])

        Shrine.deprecation("The :filename option is deprecated for the data_uri plugin, and will be removed in Shrine 3. Use the infer_extension plugin instead.") if opts[:filename]
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
          info = parse_data_uri(uri)

          content_type = info[:content_type] || DEFAULT_CONTENT_TYPE
          content      = info[:base64] ? Base64.decode64(info[:data]) : CGI.unescape(info[:data])
          filename     = opts[:data_uri_filename].call(content_type) if opts[:data_uri_filename]

          data_file = DataFile.new(content, content_type: content_type, filename: filename)
          info[:data].clear

          data_file
        end

        private

        def parse_data_uri(uri)
          scanner = StringScanner.new(uri)
          scanner.scan(DATA_REGEXP) or raise ParseError, "data URI has invalid format"
          media_type = scanner.scan(MEDIA_TYPE_REGEXP)
          base64 = scanner.scan(BASE64_REGEXP)
          scanner.scan(CONTENT_SEPARATOR) or raise ParseError, "data URI has invalid format"
          content = scanner.post_match

          { content_type: media_type, base64: !!base64, data: content }
        end
      end

      module AttachmentMethods
        def initialize(*)
          super

          name = attachment_name

          define_method :"#{name}_data_uri=" do |uri|
            send(:"#{name}_attacher").data_uri = uri
          end

          define_method :"#{name}_data_uri" do
            send(:"#{name}_attacher").data_uri
          end
        end
      end

      module AttacherMethods
        # Handles assignment of a data URI. If the regexp matches, it extracts
        # the content type, decodes it, wrappes it in a StringIO and assigns it.
        # If it fails, it sets the error message and assigns the uri in an
        # instance variable so that it shows up on the UI.
        def data_uri=(uri)
          return if uri == "" || uri.nil?

          data_file = shrine_class.data_uri(uri)
          assign(data_file)
        rescue ParseError => error
          message = shrine_class.opts[:data_uri_error_message] || error.message
          message = message.call(uri) if message.respond_to?(:call)
          errors.replace [message]
          @data_uri = uri
        end

        # Form builders require the reader as well.
        def data_uri
          @data_uri
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

      class DataFile
        attr_reader :content_type, :original_filename

        def initialize(content, content_type: nil, filename: nil)
          @content_type      = content_type
          @original_filename = filename
          @io                = StringIO.new(content)
        end

        def to_io
          @io
        end

        extend Forwardable
        delegate [:read, :size, :rewind, :eof?] => :@io

        def close
          @io.close
          @io.string.clear # deallocate string
        end
      end
    end

    register_plugin(:data_uri, DataUri)
  end
end
