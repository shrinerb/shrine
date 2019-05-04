# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/download_endpoint.md] on GitHub.
    #
    # [doc/plugins/download_endpoint.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/download_endpoint.md
    module DownloadEndpoint
      def self.load_dependencies(uploader, opts = {})
        uploader.plugin :rack_response
        uploader.plugin :_urlsafe_serialization
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:download_endpoint_storages] = opts.fetch(:storages, uploader.opts[:download_endpoint_storages])
        uploader.opts[:download_endpoint_prefix] = opts.fetch(:prefix, uploader.opts[:download_endpoint_prefix])
        uploader.opts[:download_endpoint_download_options] = opts.fetch(:download_options, uploader.opts.fetch(:download_endpoint_download_options, {}))
        uploader.opts[:download_endpoint_disposition] = opts.fetch(:disposition, uploader.opts.fetch(:download_endpoint_disposition, "inline"))
        uploader.opts[:download_endpoint_host] = opts.fetch(:host, uploader.opts[:download_endpoint_host])
        uploader.opts[:download_endpoint_redirect] = opts.fetch(:redirect, uploader.opts.fetch(:download_endpoint_redirect, false))

        Shrine.deprecation("The :storages download_endpoint option is deprecated, you should use UploadedFile#download_url for generating URLs to the download endpoint.") if uploader.opts[:download_endpoint_storages]

        uploader.assign_download_endpoint(App) unless uploader.const_defined?(:DownloadEndpoint)
      end

      module ClassMethods
        # Assigns the subclass a copy of the download endpoint class.
        def inherited(subclass)
          super
          subclass.assign_download_endpoint(@download_endpoint)
        end

        # Returns the Rack application that retrieves requested files.
        def download_endpoint
          new_download_endpoint(App)
        end

        # Assigns the subclassed endpoint as the `DownloadEndpoint` constant.
        def assign_download_endpoint(app_class)
          @download_endpoint = new_download_endpoint(app_class)

          const_set(:DownloadEndpoint, @download_endpoint)
          deprecate_constant(:DownloadEndpoint)
        end

        private

        def new_download_endpoint(app_class)
          app_class.new(
            shrine_class:     self,
            download_options: opts[:download_endpoint_download_options],
            disposition:      opts[:download_endpoint_disposition],
            redirect:         opts[:download_endpoint_redirect],
          )
        end
      end

      module FileMethods
        # Constructs the URL from the optional host, prefix, storage key and
        # uploaded file's id. For other uploaded files that aren't in the list
        # of storages it just returns their original URL.
        def url(**options)
          if download_storages && download_storages.include?(storage_key.to_sym)
            Shrine.deprecation("The :storages option for download_endpoint plugin is deprecated and will be obsolete in Shrine 3. Use UploadedFile#download_url instead.")
            download_url
          else
            super
          end
        end

        # Returns file URL on the download endpoint.
        def download_url(**options)
          FileUrl.new(self).call(**options)
        end

        private

        def download_storages
          shrine_class.opts[:download_endpoint_storages]
        end
      end

      class FileUrl
        attr_reader :file

        def initialize(file)
          @file = file
        end

        def call(host: self.host)
          [host, *prefix, path].join("/")
        end

        protected

        def path
          file.urlsafe_dump(metadata: %w[filename size mime_type])
        end

        def host
          shrine_class.opts[:download_endpoint_host]
        end

        def prefix
          shrine_class.opts[:download_endpoint_prefix]
        end

        def shrine_class
          file.shrine_class
        end
      end

      # Routes incoming requests. It first asserts that the storage is existent
      # and allowed. Afterwards it proceeds with the file download using
      # streaming.
      class App
        # Writes given options to instance variables.
        def initialize(options)
          options.each do |name, value|
            instance_variable_set("@#{name}", value)
          end
        end

        def call(env)
          request = Rack::Request.new(env)

          status, headers, body = catch(:halt) do
            error!(405, "Method Not Allowed") unless request.get?

            handle_request(request)
          end

          headers["Content-Length"] ||= body.map(&:bytesize).inject(0, :+).to_s

          [status, headers, body]
        end

        private

        def handle_request(request)
          _, *components = request.path_info.split("/")

          if components.count == 1
            uploaded_file = get_uploaded_file(components.first)
          elsif components.count == 2
            # handle legacy "/:storage/:id" URLs
            uploaded_file = @shrine_class::UploadedFile.new(
              "storage" => components.first,
              "id"      => components.last,
            )
          end

          serve_file(uploaded_file, request)
        end

        # Streams or redirects to the uploaded file.
        def serve_file(uploaded_file, request)
          if @redirect
            redirect_to_file(uploaded_file, request)
          else
            stream_file(uploaded_file, request)
          end
        end

        # Streams the uploaded file content.
        def stream_file(uploaded_file, request)
          open_file(uploaded_file, request)

          response = uploaded_file.to_rack_response(
            disposition: @disposition,
            range:       request.env["HTTP_RANGE"],
          )

          response[1]["Cache-Control"] = "max-age=#{365*24*60*60}" # cache for a year

          response
        end

        # Redirects to the uploaded file's direct URL or the specified URL proc.
        def redirect_to_file(uploaded_file, request)
          if @redirect == true
            redirect_url = uploaded_file.url
          else
            redirect_url = @redirect.call(uploaded_file, request)
          end

          [302, { "Location" => redirect_url }, []]
        end

        def open_file(uploaded_file, request)
          download_options = @download_options
          download_options = download_options.call(uploaded_file, request) if download_options.respond_to?(:call)

          uploaded_file.open(**download_options)
        end

        # Returns a Shrine::UploadedFile, or returns 404 if file doesn't exist.
        def get_uploaded_file(serialized)
          uploaded_file = @shrine_class::UploadedFile.urlsafe_load(serialized)
          not_found! unless uploaded_file.exists?
          uploaded_file
        rescue Shrine::Error # storage not found
          not_found!
        end

        def not_found!
          error!(404, "File Not Found")
        end

        # Halts the request with the error message.
        def error!(status, message)
          throw :halt, [status, { "Content-Type" => "text/plain" }, [message]]
        end
      end
    end

    register_plugin(:download_endpoint, DownloadEndpoint)
  end
end
