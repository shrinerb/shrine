# frozen_string_literal: true

require "rack"

require "json"
require "digest"

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/upload_endpoint
    module UploadEndpoint
      def self.load_dependencies(uploader, **)
        uploader.plugin :rack_file
      end

      def self.configure(uploader, **opts)
        uploader.opts[:upload_endpoint] ||= {}
        uploader.opts[:upload_endpoint].merge!(opts)
      end

      module ClassMethods
        # Returns a Rack application (object that responds to `#call`) which
        # accepts multipart POST requests to the root URL, uploads given file
        # to the specified storage, and returns that information in JSON format.
        #
        # The `storage_key` needs to be one of the registered Shrine storages.
        # Additional options can be given to override the options given on
        # plugin initialization.
        def upload_endpoint(storage_key, **options)
          Shrine::UploadEndpoint.new(
            shrine_class: self,
            storage_key:  storage_key,
            **opts[:upload_endpoint],
            **options,
          )
        end

        # Calls the upload endpoint passing the request information, and
        # returns the Rack response triple.
        #
        # It performs the same mounting logic that Rack and other web
        # frameworks use, and is meant for cases where statically mounting the
        # endpoint in the router isn't enough.
        def upload_response(storage_key, env, **options)
          script_name = env["SCRIPT_NAME"]
          path_info   = env["PATH_INFO"]

          begin
            env["SCRIPT_NAME"] += path_info
            env["PATH_INFO"]    = ""

            upload_endpoint(storage_key, **options).call(env)
          ensure
            env["SCRIPT_NAME"] = script_name
            env["PATH_INFO"]   = path_info
          end
        end
      end
    end

    register_plugin(:upload_endpoint, UploadEndpoint)
  end

  # Rack application that accepts multipart POST request to the root URL,
  # calls `#upload` with the uploaded file, and returns the uploaded file
  # information in JSON format.
  class UploadEndpoint
    CONTENT_TYPE_JSON = "application/json; charset=utf-8"
    CONTENT_TYPE_TEXT = "text/plain"

    # Writes given options to instance variables.
    def initialize(options)
      options.each do |name, value|
        instance_variable_set("@#{name}", value)
      end
    end

    # Accepts a Rack env hash, routes POST requests to the root URL, and
    # returns a Rack response triple.
    #
    # If request isn't to the root URL, a `404 Not Found` response is
    # returned. If request verb isn't GET, a `405 Method Not Allowed`
    # response is returned.
    def call(env)
      request = Rack::Request.new(env)

      status, headers, body = catch(:halt) do
        error!(404, "Not Found") unless ["", "/"].include?(request.path_info)
        error!(405, "Method Not Allowed") unless request.post?

        handle_request(request)
      end

      if Rack.release >= "3"
        headers["content-length"] ||= body.respond_to?(:bytesize) ? body.bytesize.to_s :
                                                                    body.map(&:bytesize).inject(0, :+).to_s
      else
        headers["Content-Length"] ||= body.map(&:bytesize).inject(0, :+).to_s
      end

      headers = headers.transform_keys(&:downcase) if Rack.release >= "3"

      [status, headers, body]
    end

    def inspect
      "#<#{@shrine_class}::UploadEndpoint(:#{@storage_key})>"
    end
    alias to_s inspect

    private

    # Accepts a `Rack::Request` object, uploads the file, and returns a Rack
    # response.
    def handle_request(request)
      io      = get_io(request)
      context = get_context(request)

      uploaded_file = upload(io, context, request)

      make_response(uploaded_file, request)
    end

    # Retrieves the upload from the request and verifies it.
    def get_io(request)
      file = get_multipart_upload(request)

      verify_size!(file, request)
      verify_checksum!(file, request)

      file
    end

    # Retrieves the file from "file" or "files[]" multipart POST param, and
    # converts it into an IO-like object that can be passed to `Shrine#upload`.
    def get_multipart_upload(request)
      if request.params.key?("file")
        value = request.params["file"]
      elsif request.params["files"].is_a?(Array)
        error!(400, "Too Many Files") if request.params["files"].count > 1
        value = request.params["files"].first
      end

      error!(400, "Upload Not Found") if value.nil?

      if value.is_a?(Hash) && value[:tempfile]
        @shrine_class.rack_file(value)
      elsif %i[read rewind eof? close].all? { |m| value.respond_to?(m) }
        value
      else
        error!(400, "Upload Not Valid")
      end
    end

    # Returns a hash of information containing `:action` and `:request`
    # keys, which is to be passed to `Shrine#upload`. Calls
    # `:upload_context` option if given.
    def get_context(request)
      context = { action: :upload }
      context.merge! @upload_context.call(request) if @upload_context
      context
    end

    # Calls `Shrine#upload` with the given IO and context, and returns a
    # `Shrine::UploadedFile` object. If `:upload` option is given, calls
    # that instead.
    def upload(io, context, request)
      if @upload
        @upload.call(io, context, request)
      else
        uploader.upload(io, **context)
      end
    end

    # Transforms the uploaded file object into a JSON response. It returns
    # a Rack response triple - an array consisting of a status number, hash
    # of headers, and a body enumerable. If a `:rack_response` option is
    # given, calls that instead.
    def make_response(uploaded_file, request)
      if @rack_response
        @rack_response.call(uploaded_file, request)
      else
        if @url
          url  = resolve_url(uploaded_file, request)
          body = { data: uploaded_file, url: url }.to_json
        else
          body = uploaded_file.to_json
        end

        [200, { "Content-Type" => CONTENT_TYPE_JSON }, [body]]
      end
    end

    def resolve_url(uploaded_file, request)
      case @url
      when true then uploaded_file.url
      when Hash then uploaded_file.url(**@url)
      else           @url.call(uploaded_file, request)
      end
    end

    def verify_size!(file, request)
      error!(413, "Upload Too Large") if @max_size && file.size > @max_size
    end

    # Verifies the provided checksum against the received file.
    def verify_checksum!(file, request)
      return unless request.env.key?("HTTP_CONTENT_MD5")

      provided_checksum = request.env["HTTP_CONTENT_MD5"]

      error!(400, "The Content-MD5 you specified was invalid") if provided_checksum.length != 24

      calculated_checksum = Digest::MD5.file(file.path).base64digest
      error!(460, "The Content-MD5 you specified did not match what was recieved") if provided_checksum != calculated_checksum
    end

    # Used for early returning an error response.
    def error!(status, message)
      headers = { "Content-Type" => CONTENT_TYPE_TEXT }

      headers = headers.transform_keys(&:downcase) if Rack.release >= "3"

      throw :halt, [status, headers, [message]]
    end

    # Returns the uploader around the specified storage.
    def uploader
      @shrine_class.new(@storage_key)
    end
  end
end
