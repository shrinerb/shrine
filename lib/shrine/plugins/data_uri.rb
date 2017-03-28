require "base64"
require "strscan"
require "cgi/util"
require "tempfile"
require "forwardable"

class Shrine
  module Plugins
    # The `data_uri` plugin enables you to upload files as [data URIs].
    # This plugin is useful for example when using [HTML5 Canvas].
    #
    #     plugin :data_uri
    #
    # If your attachment is called "avatar", this plugin will add
    # `#avatar_data_uri` and `#avatar_data_uri=` methods to your model.
    #
    #     user.avatar #=> nil
    #     user.avatar_data_uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
    #     user.avatar #=> #<Shrine::UploadedFile>
    #
    #     user.avatar.mime_type         #=> "image/png"
    #     user.avatar.size              #=> 43423
    #
    # You can also use `#data_uri=` and `#data_uri` methods directly on the
    # `Shrine::Attacher` (which the model methods just delegate to):
    #
    #     attacher.data_uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
    #
    # If the data URI wasn't correctly parsed, an error message will be added to
    # the attachment column. You can change the default error message:
    #
    #     plugin :data_uri, error_message: "data URI was invalid"
    #     plugin :data_uri, error_message: ->(uri) { I18n.t("errors.data_uri_invalid") }
    #
    # If you just want to parse the data URI and create an IO object from it,
    # you can do that with `Shrine.data_uri`. If the data URI cannot be parsed,
    # a `Shrine::Plugins::DataUri::ParseError` will be raised.
    #
    #     Shrine.data_uri("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA")
    #     #=> #<Shrine::Plugins::DataUri::DataFile>
    #
    # When the content type is ommited, `text/plain` is assumed. The parser
    # also supports raw data URIs which aren't base64-encoded.
    #
    #     Shrine.data_uri("data:text/plain,raw%20content")
    #
    # The created IO object won't convey any file extension (because it doesn't
    # have a filename), but you can generate a filename based on the content
    # type of the data URI:
    #
    #     plugin :data_uri, filename: ->(content_type) do
    #       extension = MIME::Types[content_type].first.preferred_extension
    #       "data_uri.#{extension}"
    #     end
    #
    # This plugin also adds a `UploadedFile#data_uri` method (and `#base64`),
    # which returns a base64-encoded data URI of any UploadedFile:
    #
    #     uploaded_file.data_uri #=> "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
    #     uploaded_file.base64   #=> "iVBORw0KGgoAAAANSUhEUgAAAAUA"
    #
    # [data URIs]: https://tools.ietf.org/html/rfc2397
    # [HTML5 Canvas]: https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API
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
      end

      module ClassMethods
        # Parses the given data URI and creates an IO object from it.
        #
        #     Shrine.data_uri("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA")
        #     #=> #<Shrine::Plugins::DataUri::DataFile>
        def data_uri(uri)
          info = parse_data_uri(uri)

          content_type = info[:content_type] || DEFAULT_CONTENT_TYPE
          content      = info[:base64] ? Base64.decode64(info[:data]) : CGI.unescape(info[:data])
          filename     = opts[:data_uri_filename]
          filename     = filename.call(content_type) if filename

          data_file = DataFile.new(content, content_type: content_type, filename: filename)
          [info[:data], content].each(&:clear) # deallocate strings

          data_file
        end

        private

        def parse_data_uri(uri)
          scanner = StringScanner.new(uri)
          scanner.scan(DATA_REGEXP) or raise ParseError, "data URI has invalid format"
          media_type = scanner.scan(MEDIA_TYPE_REGEXP)
          base64 = scanner.scan(BASE64_REGEXP)
          scanner.scan(CONTENT_SEPARATOR) or raise ParseError, "data URI has invalid format"

          content_type = media_type[/^[^;]+/] if media_type

          {
            content_type: content_type,
            base64:       !!base64,
            data:         scanner.post_match,
          }
        end
      end

      module AttachmentMethods
        def initialize(*)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{@name}_data_uri=(uri)
              #{@name}_attacher.data_uri = uri
            end

            def #{@name}_data_uri
              #{@name}_attacher.data_uri
            end
          RUBY
        end
      end

      module AttacherMethods
        # Handles assignment of a data URI. If the regexp matches, it extracts
        # the content type, decodes it, wrappes it in a StringIO and assigns it.
        # If it fails, it sets the error message and assigns the uri in an
        # instance variable so that it shows up on the UI.
        def data_uri=(uri)
          return if uri == ""

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
          result = Base64.encode64(binary).chomp
          binary.clear # deallocate string
          result
        end
      end

      class DataFile
        attr_reader :tempfile, :content_type, :original_filename

        def initialize(content, content_type: nil, filename: nil)
          @content_type = content_type
          @original_filename = filename

          @tempfile = Tempfile.new("shrine-data_uri", binmode: true)
          @tempfile.write(content)
          @tempfile.open
        end

        def path
          @tempfile.path
        end

        extend Forwardable
        delegate Shrine::IO_METHODS.keys => :tempfile

        def close
          @tempfile.close! # delete the tempfile
        end
      end
    end

    register_plugin(:data_uri, DataUri)
  end
end
