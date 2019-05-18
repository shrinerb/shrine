# frozen_string_literal: true

require "rack"

require "json"
require "digest"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/upload_endpoint.md] on GitHub.
    #
    # [doc/plugins/upload_endpoint.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/upload_endpoint.md
    module UploadEndpoint
      def self.load_dependencies(uploader, opts = {})
        uploader.plugin :rack_file
      end

      def self.configure(uploader, opts = {})
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

      headers["Content-Length"] ||= body.map(&:bytesize).inject(0, :+).to_s

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

    # Retrieves the "file" multipart request parameter, and returns an
    # IO-like object that can be passed to `Shrine#upload`.
    def get_io(request)
      file = request.params["file"]

      error!(400, "Upload Not Found") if file.nil?
      error!(400, "Upload Not Valid") unless file.is_a?(Hash) && file[:tempfile]
      error!(413, "Upload Too Large") if @max_size && file[:tempfile].size > @max_size

      verify_checksum!(file[:tempfile], request.env["HTTP_CONTENT_MD5"]) if request.env["HTTP_CONTENT_MD5"]

      @shrine_class.rack_file(file)
    end

    # Returns a hash of information containing `:action` and `:request`
    # keys, which is to be passed to `Shrine#upload`. Calls
    # `:upload_context` option if given.
    def get_context(request)
      context = { action: :upload, phase: :upload, request: request }
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
        uploader.upload(io, context)
      end
    end

    # Transforms the uploaded file object into a JSON response. It returns
    # a Rack response triple - an array consisting of a status number, hash
    # of headers, and a body enumerable. If a `:rack_response` option is
    # given, calls that instead.
    def make_response(object, request)
      if @rack_response
        @rack_response.call(object, request)
      else
        [200, { "Content-Type" => CONTENT_TYPE_JSON }, [object.to_json]]
      end
    end

    # Verifies the provided checksum against the received file.
    def verify_checksum!(file, provided_checksum)
      error!(400, "The Content-MD5 you specified was invalid") if provided_checksum.length != 24

      calculated_checksum = Digest::MD5.file(file.path).base64digest
      error!(460, "The Content-MD5 you specified did not match what was recieved") if provided_checksum != calculated_checksum
    end

    # Used for early returning an error response.
    def error!(status, message)
      throw :halt, [status, { "Content-Type" => CONTENT_TYPE_TEXT }, [message]]
    end

    # Returns the uploader around the specified storage.
    def uploader
      @shrine_class.new(@storage_key)
    end
  end

  # backwards compatibility
  Plugins::UploadEndpoint.const_set(:App, UploadEndpoint)
  Plugins::UploadEndpoint.deprecate_constant(:App)
end
