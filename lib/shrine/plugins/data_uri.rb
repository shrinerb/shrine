require "base64"

class Shrine
  module Plugins
    module DataUri
      def self.configure(uploader, error_message:)
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
        REGEXP = /\Adata:([-\w]+\/[-\w\+\.]+)?;base64,(.*)/m

        def data_uri=(uri)
          return if uri == ""

          if match = uri.match(REGEXP)
            content_type = match[1] || "text/plain"
            content      = Base64.decode64(match[2])

            set DataFile.new(content, content_type: content_type)
          else
            message = shrine_class.opts[:data_uri_error_message]
            message = message.call(uri) if message.respond_to?(:call)
            errors << message
            @data_uri = uri
          end
        end

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
