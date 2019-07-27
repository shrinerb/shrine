# frozen_string_literal: true

require "down"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/remote_url.md] on GitHub.
    #
    # [doc/plugins/remote_url.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/remote_url.md
    module RemoteUrl
      class DownloadError < Error; end

      LOG_SUBSCRIBER = -> (event) do
        Shrine.logger.info "Remote URL (#{event.duration}ms) – #{{
          remote_url:       event[:remote_url],
          download_options: event[:download_options],
          uploader:         event[:uploader],
        }.inspect}"
      end

      DOWNLOADER = -> (url, options) do
        begin
          Down.download(url, options)
        rescue Down::Error => error
          raise DownloadError, error.message
        end
      end

      def self.load_dependencies(uploader, *)
        uploader.plugin :validation
      end

      def self.configure(uploader, **opts)
        uploader.opts[:remote_url] ||= { downloader: DOWNLOADER, log_subscriber: LOG_SUBSCRIBER }
        uploader.opts[:remote_url].merge!(opts)

        unless uploader.opts[:remote_url].key?(:max_size)
          fail Error, "The :max_size option is required for remote_url plugin"
        end

        # instrumentation plugin integration
        if uploader.respond_to?(:subscribe)
          uploader.subscribe(:remote_url, &uploader.opts[:remote_url][:log_subscriber])
        end
      end

      module AttachmentMethods
        def included(klass)
          super

          return unless options[:type] == :model

          name = attachment_name

          define_method :"#{name}_remote_url=" do |url|
            send(:"#{name}_attacher").assign_remote_url(url)
          end

          define_method :"#{name}_remote_url" do
            # form builders require the reader method
          end
        end
      end

      module ClassMethods
        # Downloads the file using the "down" gem or a custom downloader.
        # Checks the file size and terminates the download early if the file
        # is too big.
        def remote_url(url, **options)
          options = { max_size: opts[:remote_url][:max_size] }.merge(options)

          instrument_remote_url(url, options) do
            opts[:remote_url][:downloader].call(url, options)
          end
        end

        private

        # Sends a `remote_url.shrine` event for instrumentation plugin.
        def instrument_remote_url(url, options, &block)
          return yield unless respond_to?(:instrument)

          instrument(:remote_url, remote_url: url, download_options: options, &block)
        end
      end

      module AttacherMethods
        # Downloads the remote file and assigns it. If download failed, sets
        # the error message and assigns the url to an instance variable so that
        # it shows up in the form.
        def assign_remote_url(url, downloader: {}, **options)
          return if url == "" || url.nil?

          downloaded_file = shrine_class.remote_url(url, downloader)
          attach_cached(downloaded_file, **options)
        rescue DownloadError => error
          errors.clear << remote_url_error_message(url, error)
          false
        end

        private

        # Generates an error message for failed remote URL download.
        def remote_url_error_message(url, error)
          message = shrine_class.opts[:remote_url][:error_message]
          message = message.call *[url, error].take(message.arity.abs) if message.respond_to?(:call)
          message || "download failed: #{error.message}"
        end
      end
    end

    register_plugin(:remote_url, RemoteUrl)
  end
end
