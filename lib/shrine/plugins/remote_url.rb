class Shrine
  module Plugins
    # The remote_url plugin allows you to attach files from a remote location.
    #
    #     plugin :remote_url, max_size: 20*1024*1024
    #
    # If for example your attachment is called "avatar", this plugin will add
    # `#avatar_remote_url` and `#avatar_remote_url=` methods to your model.
    #
    #     user.avatar #=> nil
    #     user.avatar_remote_url = "http://example.com/cool-image.png"
    #     user.avatar #=> #<Shrine::UploadedFile>
    #
    #     user.avatar.mime_type         #=> "image/png"
    #     user.avatar.size              #=> 43423
    #     user.avatar.original_filename #=> "cool-image.png"
    #
    # The file will by default be downloaded using Ruby's open-uri standard
    # library. Following redirects is disabled for security reasons. It's also
    # good practice to limit the filesize of the remote file:
    #
    #     plugin :remote_url, max_size: 20*1024*1024 # 20 MB
    #
    # Now if a file that is bigger than 20MB is assigned, Shrine will terminate
    # the download as soon as it gets the "Content-Length" header, or the
    # buffer size surpasses the maximum size. However, if for whatever reason
    # you don't want to limit the maximum file size, you can set `:max_size` to
    # nil:
    #
    #     plugin :remote_url, max_size: nil
    #
    # If download fails, either because the remote file wasn't found, was too
    # large, or the request redirected, an error will be added to the
    # attachment. You can change the default error message:
    #
    #     plugin :remote_url, error_message: "download failed"
    #     plugin :remote_url, error_message: ->(url) { I18n.t("errors.download_failed") }
    #
    # Finally, if for some reason the way the file is downloaded doesn't suit
    # your needs, you can provide a custom downloader:
    #
    #     plugin :remote_url, downloader: ->(url) do
    #       request = RestClient::Request.new(method: :get, url: url, raw_response: true)
    #       response = request.execute
    #       response.file
    #     end
    module RemoteUrl
      DEFAULT_ERROR_MESSAGE = "file was not found or was too large"

      def self.load_dependencies(uploader, downloader: :open_uri, **)
        case downloader
        when :open_uri then require "down"
        end
      end

      def self.configure(uploader, downloader: :open_uri, error_message: nil, max_size:)
        uploader.opts[:remote_url_downloader] = downloader
        uploader.opts[:remote_url_error_message] = error_message || DEFAULT_ERROR_MESSAGE
        uploader.opts[:remote_url_max_size] = max_size
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
        # Downloads the remote file and assigns it. If download failed, sets
        # the error message and assigns the url to an instance variable so that
        # it shows up in the form.
        def remote_url=(url)
          return if url == ""

          if downloaded_file = download(url)
            assign(downloaded_file)
          else
            message = shrine_class.opts[:remote_url_error_message]
            message = message.call(url) if message.respond_to?(:call)
            errors << message
            @remote_url = url
          end
        end

        # Form builders require the reader as well.
        def remote_url
          @remote_url
        end

        private

        # Downloads the file using the "down" gem or a custom downloader.
        # Checks the file size and terminates the download early if the file
        # is too big.
        def download(url)
          downloader = shrine_class.opts[:remote_url_downloader]
          max_size = shrine_class.opts[:remote_url_max_size]

          if downloader.is_a?(Symbol)
            send(:"download_with_#{downloader}", url, max_size: max_size)
          else
            downloader.call(url, max_size: max_size)
          end
        end

        # We silence any download errors, because for the user's point of view
        # the download simply failed.
        def download_with_open_uri(url, max_size:)
          Down.download(url, max_size: max_size)
        rescue Down::Error
        end
      end
    end

    register_plugin(:remote_url, RemoteUrl)
  end
end
