require "down"

class Shrine
  module Plugins
    # The `remote_url` plugin allows you to attach files from a remote location.
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
    # You can also use `#remote_url=` and `#remote_url` methods directly on the
    # `Shrine::Attacher`:
    #
    #     attacher.remote_url = "http://example.com/cool-image.png"
    #
    # The file will by default be downloaded using [Down], which is a wrapper
    # around the `open-uri` standard library. Note that Down expects the given
    # URL to be URI-encoded.
    #
    # ## Maximum size
    #
    # It's a good practice to limit the maximum filesize of the remote file:
    #
    #     plugin :remote_url, max_size: 20*1024*1024 # 20 MB
    #
    # Now if a file that is bigger than 20MB is assigned, download will be
    # terminated as soon as it gets the "Content-Length" header, or the
    # size of currently downloaded content surpasses the maximum size.
    # However, if for whatever reason you don't want to limit the maximum file
    # size, you can set `:max_size` to nil:
    #
    #     plugin :remote_url, max_size: nil
    #
    # ## Custom downloader
    #
    # If you want to customize how the file is downloaded, you can override the
    # `:downloader` parameter and provide your own implementation. For example,
    # you can use the HTTP.rb Down backend for downloading:
    #
    #     require "down/http"
    #
    #     plugin :remote_url, max_size: 20*1024*1024, downloader: ->(url, max_size:) do
    #       Down::Http.download(url, max_size: max_size, follow: { max_hops: 4 }, timeout: { read: 3 })
    #     end
    #
    # ## Errors
    #
    # If download errors, the error is rescued and a validation error is added
    # equal to the error message. You can change the default error message:
    #
    #     plugin :remote_url, error_message: "download failed"
    #     plugin :remote_url, error_message: ->(url, error) { I18n.t("errors.download_failed") }
    #
    # ## Background
    #
    # If you want the file to be downloaded from the URL in the background, you
    # can use the [shrine-url] storage which allows you to assign a custom URL
    # as cached file ID, and pair that with the `backgrounding` plugin.
    #
    # [Down]: https://github.com/janko-m/down
    # [Addressable]: https://github.com/sporkmonger/addressable
    # [shrine-url]: https://github.com/janko-m/shrine-url
    module RemoteUrl
      def self.configure(uploader, opts = {})
        raise Error, "The :max_size option is required for remote_url plugin" if !opts.key?(:max_size) && !uploader.opts.key?(:remote_url_max_size)

        uploader.opts[:remote_url_downloader] = opts.fetch(:downloader, uploader.opts.fetch(:remote_url_downloader, :open_uri))
        uploader.opts[:remote_url_max_size] = opts.fetch(:max_size, uploader.opts[:remote_url_max_size])
        uploader.opts[:remote_url_error_message] = opts.fetch(:error_message, uploader.opts[:remote_url_error_message])
      end

      module AttachmentMethods
        def initialize(*)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{@name}_remote_url=(url)
              #{@name}_attacher.remote_url = url
            end

            def #{@name}_remote_url
              #{@name}_attacher.remote_url
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

          begin
            downloaded_file = download(url)
          rescue => error
            download_error = error
          end

          if downloaded_file
            assign(downloaded_file)
          else
            message = download_error_message(url, download_error)
            errors.replace [message]
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
          downloader = method(:"download_with_#{downloader}") if downloader.is_a?(Symbol)
          max_size = shrine_class.opts[:remote_url_max_size]

          downloader.call(url, max_size: max_size)
        end

        # We silence any download errors, because for the user's point of view
        # the download simply failed.
        def download_with_open_uri(url, max_size:)
          Down.download(url, max_size: max_size)
        end

        def download_error_message(url, error)
          if message = shrine_class.opts[:remote_url_error_message]
            if message.respond_to?(:call)
              args = [url, error].take(message.arity.abs)
              message = message.call(*args)
            end
          else
            message = "download failed"
            message = "#{message}: #{error.message}" if error
          end

          message
        end
      end
    end

    register_plugin(:remote_url, RemoteUrl)
  end
end
