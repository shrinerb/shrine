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
        uploader.opts[:download_endpoint] ||= { disposition: "inline", download_options: {} }
        uploader.opts[:download_endpoint].merge!(opts)
      end

      module ClassMethods
        # Returns the Rack application that retrieves requested files.
        def download_endpoint(**options)
          App.new(
            shrine_class: self,
            **opts[:download_endpoint],
            **options,
          )
        end
      end

      module FileMethods
        # Returns file URL on the download endpoint.
        def download_url(**options)
          FileUrl.new(self).call(**options)
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
          options[:host]
        end

        def prefix
          options[:prefix]
        end

        def options
          file.shrine_class.opts[:download_endpoint]
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

        def inspect
          "#<#{@shrine_class}::DownloadEndpoint>"
        end
        alias to_s inspect

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
