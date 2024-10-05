# frozen_string_literal: true

require 'openssl'
require 'base64'

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/download_endpoint
    module DownloadEndpoint
      def self.load_dependencies(uploader, **)
        uploader.plugin :rack_response
        uploader.plugin :_urlsafe_serialization
      end

      def self.configure(uploader, **opts)
        uploader.opts[:download_endpoint] ||= { disposition: "inline", download_options: {} }
        uploader.opts[:download_endpoint].merge!(opts)
      end

      module ClassMethods
        # Returns the Rack application that retrieves requested files.
        def download_endpoint(**options)
          Shrine::DownloadEndpoint.new(
            shrine_class: self,
            **opts[:download_endpoint],
            **options,
          )
        end

        # Calls the download endpoint passing the request information, and
        # returns the Rack response triple.
        #
        # It uses a trick where it removes the download path prefix from the
        # path info before calling the Rack app, which is what web framework
        # routers do before they're calling a mounted Rack app.
        def download_response(env, **options)
          script_name = env["SCRIPT_NAME"]
          path_info   = env["PATH_INFO"]

          prefix = opts[:download_endpoint][:prefix]
          match  = path_info.match(/^\/#{prefix}/)

          fail Error, "request path must start with \"/#{prefix}\", but is \"#{path_info}\"" unless match

          begin
            env["SCRIPT_NAME"] += match.to_s
            env["PATH_INFO"]    = match.post_match

            download_endpoint(**options).call(env)
          ensure
            env["SCRIPT_NAME"] = script_name
            env["PATH_INFO"]   = path_info
          end
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

        def call(host: self.host, expires_in: nil)
          path = file.urlsafe_dump(metadata: %w[filename size mime_type])

          query = signature_as_query(path: path, expires_in: expires_in)

          path = [host, *prefix, path].join("/")
          path += "?#{query}" if query
          path
        end

        protected

        def signature_as_query(path:, expires_in:)
          expires_in = default_expires_in if expires_in.nil?
          raise(Error, "secret_key is required for expiring URLs") if !secret_key && expires_in
          raise(Error, "expires_in is required for expiring URLs") if secret_key && !expires_in

          return nil unless expires_in

          expires_at = (Time.now + expires_in).to_i
          signature = OpenSSL::HMAC.digest(
            OpenSSL::Digest::SHA256.new,
            secret_key,
            "#{path}--#{expires_at}"
          )

          Rack::Utils.build_query(
            signature: Base64.urlsafe_encode64(signature),
            expires_at: expires_at
          )
        end

        def host
          options[:host]
        end

        def prefix
          options[:prefix]
        end

        def default_expires_in
          options[:expires_in]
        end

        def secret_key
          options[:secret_key]
        end

        def options
          file.shrine_class.opts[:download_endpoint]
        end
      end
    end

    register_plugin(:download_endpoint, DownloadEndpoint)
  end


  # Routes incoming requests. It first asserts that the storage is existent
  # and allowed. Afterwards it proceeds with the file download using
  # streaming.
  class DownloadEndpoint
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

      headers = Rack::Headers[headers] if Rack.release >= "3"
      headers["Content-Length"] ||= body.respond_to?(:bytesize) ? body.bytesize.to_s :
                                                                  body.map(&:bytesize).inject(0, :+).to_s

      [status, headers, body]
    end

    def inspect
      "#<#{@shrine_class}::DownloadEndpoint>"
    end
    alias to_s inspect

    private

    def handle_request(request)
      _, serialized, * = request.path_info.split("/")
      signature, expires_at = request.params.values_at("signature", "expires_at")

      check_signature!(serialized, signature, expires_at) if @secret_key

      uploaded_file = get_uploaded_file(serialized)

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
    rescue Shrine::FileNotFound
      not_found!
    end

    # Deserializes a Shrine::UploadedFile from a URL component. Returns 404 if
    # storage is not found.
    def get_uploaded_file(serialized)
      @shrine_class::UploadedFile.urlsafe_load(serialized)
    rescue Shrine::Error # storage not found
      not_found!
    rescue JSON::ParserError, ArgumentError => error # invalid serialized component
      raise if error.is_a?(ArgumentError) && error.message != "invalid base64"
      bad_request!("Invalid serialized file")
    end

    def check_signature!(serialized, signature, expires_at)
      if expires_at && expires_at.to_i < Time.now.to_i
        error!(400, "URL has expired")
      end

      calculated_signature = OpenSSL::HMAC.digest(
        OpenSSL::Digest::SHA256.new,
        @secret_key,
        "#{serialized}--#{expires_at}"
      )

      if !Rack::Utils.secure_compare(signature, Base64.urlsafe_encode64(calculated_signature))
        error!(403, "Signature does not match")
      end
    end

    def not_found!
      error!(404, "File Not Found")
    end

    def bad_request!(message)
      error!(400, message)
    end

    # Halts the request with the error message.
    def error!(status, message)
      throw :halt, [status, { "Content-Type" => "text/plain" }, [message]]
    end
  end
end
