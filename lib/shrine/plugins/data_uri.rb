require "base64"

class Shrine
  module Plugins
    # The data_uri plugin enables you to upload files in form of [data URIs].
    # This plugin is useful if the application is using [HTML5 Canvas].
    #
    #     plugin :data_uri
    #
    # If for example your attachment is called "avatar", this plugin will add
    # `#avatar_data_uri` and `#avatar_data_uri=` methods to your model.
    #
    #     user.avatar #=> nil
    #     user.avatar_data_uri = "data:image/jpeg;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
    #     user.avatar #=> #<Shrine::UploadedFile>
    #
    #     user.avatar.mime_type         #=> "image/jpeg"
    #     user.avatar.size              #=> 43423
    #     user.avatar.original_filename #=> nil
    #
    # If the data URI wasn't correctly parsed, an error message will added to
    # the attachment column. You can change the default error message:
    #
    #     plugin :data_uri, error_message: "data URI was invalid"
    #     plugin :data_uri, error_message: ->(uri) { I18n.t("errors.data_uri_invalid") }
    #
    # [data URIs]: https://tools.ietf.org/html/rfc2397
    # [HTML5 Canvas]: https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API
    module DataUri
      DEFAULT_ERROR_MESSAGE = "data URI was invalid"
      DEFAULT_CONTENT_TYPE = "text/plain"
      DATA_URI_REGEXP = /\Adata:([-\w]+\/[-\w\+\.]+)?;base64,(.*)/m

      def self.configure(uploader, error_message: DEFAULT_ERROR_MESSAGE)
        uploader.opts[:data_uri_error_message] = error_message
      end

      module AttachmentMethods
        def initialize(name, *args)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}_data_uri=(uri)
              #{name}_attacher.data_uri = uri
            end

            def #{name}_data_uri
              #{name}_attacher.data_uri
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
            content      = Base64.decode64(match[2])

            assign DataFile.new(content, content_type: content_type)
          else
            message = shrine_class.opts[:data_uri_error_message]
            message = message.call(uri) if message.respond_to?(:call)
            errors << message
            @data_uri = uri
          end
        end

        # Form builders require the reader as well.
        def data_uri
          @data_uri
        end
      end

      class DataFile < StringIO
        attr_reader :content_type

        def initialize(content, content_type: nil)
          @content_type = content_type
          super(content)
        end
      end
    end

    register_plugin(:data_uri, DataUri)
  end
end
