# frozen_string_literal: true

require "down"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/remote_url.md] on GitHub.
    #
    # [doc/plugins/remote_url.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/remote_url.md
    module RemoteUrl
      def self.configure(uploader, opts = {})
        raise Error, "The :max_size option is required for remote_url plugin" if !opts.key?(:max_size) && !uploader.opts.key?(:remote_url_max_size)

        uploader.opts[:remote_url_downloader] = opts.fetch(:downloader, uploader.opts.fetch(:remote_url_downloader, :open_uri))
        uploader.opts[:remote_url_max_size] = opts.fetch(:max_size, uploader.opts[:remote_url_max_size])
        uploader.opts[:remote_url_error_message] = opts.fetch(:error_message, uploader.opts[:remote_url_error_message])
      end

      module AttachmentMethods
        def initialize(name, **options)
          super

          define_method :"#{name}_remote_url=" do |url|
            send(:"#{name}_attacher").remote_url = url
          end

          define_method :"#{name}_remote_url" do
            send(:"#{name}_attacher").remote_url
          end
        end
      end

      module AttacherMethods
        # Downloads the remote file and assigns it. If download failed, sets
        # the error message and assigns the url to an instance variable so that
        # it shows up in the form.
        def assign_remote_url(url, downloader: {}, **options)
          return if url == "" || url.nil?

          begin
            downloaded_file = download(url, downloader)
          rescue => error
            download_error = error
          end

          if downloaded_file
            assign(downloaded_file, **options)
          else
            message = download_error_message(url, download_error)
            errors.replace [message]
            @remote_url = url
          end
        end

        # Alias for #assign_remote_url.
        def remote_url=(url)
          assign_remote_url(url)
        end

        # Form builders require the reader as well.
        def remote_url
          @remote_url
        end

        private

        # Downloads the file using the "down" gem or a custom downloader.
        # Checks the file size and terminates the download early if the file
        # is too big.
        def download(url, options)
          downloader = shrine_class.opts[:remote_url_downloader]
          downloader = method(:"download_with_#{downloader}") if downloader.is_a?(Symbol)
          max_size = shrine_class.opts[:remote_url_max_size]

          downloader.call(url, { max_size: max_size }.merge(options))
        end

        # We silence any download errors, because for the user's point of view
        # the download simply failed.
        def download_with_open_uri(url, options)
          Down.download(url, options)
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
