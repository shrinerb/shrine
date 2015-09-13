class Uploadie
  module Plugins
    module RemoteUrl
      def self.load_dependencies(uploader, downloader: :open_uri, **)
        case downloader
        when :open_uri then require "uploadie/utils"
        end
      end

      def self.configure(uploader, downloader: :open_uri, error_message:)
        uploader.opts[:remote_url_downloader] = downloader
        uploader.opts[:remote_url_error_message] = error_message
      end

      module AttachmentMethods
        def initialize(name, *args)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}_remote_url=(url)
              #{name}_attacher.remote_url = url
            end

            def #{name}_remote_url
              #{name}_attacher.remote_url
            end
          RUBY
        end
      end

      module AttacherMethods
        def remote_url=(url)
          return if url == ""

          @remote_url = url
          downloaded_file = download(url)
          set(downloaded_file)
        end

        def remote_url
          @remote_url
        end

        def validate
          super
          if remote_url && !get
            error_message = uploadie_class.opts[:remote_url_error_message]
            error_message = error_message.call(url) if error_message.respond_to?(:call)
            errors << error_message
          end
        end

        private

        def download(url)
          downloader = uploadie_class.opts[:remote_url_downloader]

          if downloader.is_a?(Symbol)
            send(:"download_with_#{downloader}", url)
          else
            downloader.call(url)
          end
        end

        def download_with_open_uri(url)
          Uploadie::Utils.download(url)
        rescue Uploadie::Error
        end
      end
    end

    register_plugin(:remote_url, RemoteUrl)
  end
end
