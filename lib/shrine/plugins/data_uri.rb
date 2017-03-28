require "base64"
require "stringio"

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
    # `Shrine::Attacher`:
    #
    #     attacher.data_uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
    #
    # If you want the uploaded file to have an extension, you can generate a
    # filename based on the content type of the data URI:
    #
    #     plugin :data_uri, filename: ->(content_type) do
    #       extension = MIME::Types[content_type].first.preferred_extension
    #       "data_uri.#{extension}"
    #     end
    #
    # If the data URI wasn't correctly parsed, an error message will be added to
    # the attachment column. You can change the default error message:
    #
    #     plugin :data_uri, error_message: "data URI was invalid"
    #     plugin :data_uri, error_message: ->(uri) { I18n.t("errors.data_uri_invalid") }
    #
    # This plugin also adds a `UploadedFile#data_uri` method (and `#base64`),
    # which returns a base64-encoded data URI of any UploadedFile:
    #
    #     user.avatar.data_uri #=> "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
    #     user.avatar.base64   #=> "iVBORw0KGgoAAAANSUhEUgAAAAUA"
    #
    # [data URIs]: https://tools.ietf.org/html/rfc2397
    # [HTML5 Canvas]: https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API
    module DataUri
      DEFAULT_ERROR_MESSAGE = "data URI was invalid"
      DEFAULT_CONTENT_TYPE = "text/plain"
      DATA_URI_REGEXP = /\Adata:([-\w.+]+\/[-\w.+]+)?(;base64)?,(.*)\z/m

      def self.configure(uploader, opts = {})
        uploader.opts[:data_uri_filename] = opts.fetch(:filename, uploader.opts[:data_uri_filename])
        uploader.opts[:data_uri_error_message] = opts.fetch(:error_message, uploader.opts[:data_uri_error_message])
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

          if match = uri.match(DATA_URI_REGEXP)
            content_type = match[1] || DEFAULT_CONTENT_TYPE
            content      = match[2] ? Base64.decode64(match[3]) : match[3]
            filename     = shrine_class.opts[:data_uri_filename]
            filename     = filename.call(content_type) if filename

            assign DataFile.new(content, content_type: content_type, filename: filename)
          else
            message = shrine_class.opts[:data_uri_error_message] || DEFAULT_ERROR_MESSAGE
            message = message.call(uri) if message.respond_to?(:call)
            errors.replace [message]
            @data_uri = uri
          end
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

      class DataFile < StringIO
        attr_reader :content_type, :original_filename

        def initialize(content, content_type: nil, filename: nil)
          @content_type = content_type
          @original_filename = filename
          super(content)
        end
      end
    end

    register_plugin(:data_uri, DataUri)
  end
end
