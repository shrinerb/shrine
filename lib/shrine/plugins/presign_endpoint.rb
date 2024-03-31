# frozen_string_literal: true

require "rack"

require "json"

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/presign_endpoint
    module PresignEndpoint
      def self.configure(uploader, **opts)
        uploader.opts[:presign_endpoint] ||= {}
        uploader.opts[:presign_endpoint].merge!(opts)
      end

      module ClassMethods
        # Returns a Rack application (object that responds to `#call`) which
        # accepts GET requests to the root URL, calls the specified storage to
        # generate the presign, and returns that information in JSON format.
        #
        # The `storage_key` needs to be one of the registered Shrine storages.
        # Additional options can be given to override the options given on
        # plugin initialization.
        def presign_endpoint(storage_key, **options)
          Shrine::PresignEndpoint.new(
            shrine_class: self,
            storage_key:  storage_key,
            **opts[:presign_endpoint],
            **options,
          )
        end

        # Calls the presign endpoint passing the request information, and
        # returns the Rack response triple.
        #
        # It performs the same mounting logic that Rack and other web
        # frameworks use, and is meant for cases where statically mounting the
        # endpoint in the router isn't enough.
        def presign_response(storage_key, env, **options)
          script_name = env["SCRIPT_NAME"]
          path_info   = env["PATH_INFO"]

          begin
            env["SCRIPT_NAME"] += path_info
            env["PATH_INFO"]    = ""

            presign_endpoint(storage_key, **options).call(env)
          ensure
            env["SCRIPT_NAME"] = script_name
            env["PATH_INFO"]   = path_info
          end
        end
      end
    end

    register_plugin(:presign_endpoint, PresignEndpoint)
  end

  # Rack application that accepts GET request to the root URL, calls
  # `#presign` on the specified storage, and returns that information in
  # JSON format.
  class PresignEndpoint
    CONTENT_TYPE_JSON = "application/json; charset=utf-8"
    CONTENT_TYPE_TEXT = "text/plain"

    # Writes given options to instance variables.
    def initialize(options)
      options.each do |name, value|
        instance_variable_set("@#{name}", value)
      end
    end

    # Accepts a Rack env hash, routes GET requests to the root URL, and
    # returns a Rack response triple.
    #
    # If request isn't to the root URL, a `404 Not Found` response is
    # returned. If request verb isn't GET, a `405 Method Not Allowed`
    # response is returned.
    def call(env)
      request = Rack::Request.new(env)

      status, headers, body = catch(:halt) do
        error!(404, "Not Found") unless ["", "/"].include?(request.path_info)

        if request.get?
          handle_request(request)
        elsif request.options?
          handle_options_request(request)
        else
          error!(405, "Method Not Allowed")
        end
      end

      if Rack.release >= "3"
        headers["content-length"] ||= body.respond_to?(:bytesize) ? body.bytesize.to_s :
                                                                    body.map(&:bytesize).inject(0, :+).to_s
      else
        headers["Content-Length"] ||= body.map(&:bytesize).inject(0, :+).to_s
      end

      if Rack.release >= "3"
        [status, headers.transform_keys(&:downcase), body]
      else
        [status, headers, body]
      end
    end

    def inspect
      "#<#{@shrine_class}::PresignEndpoint(:#{@storage_key})>"
    end
    alias to_s inspect

    private

    # Accepts a `Rack::Request` object, generates the presign, and returns a
    # Rack response.
    def handle_request(request)
      location = get_presign_location(request)
      options  = get_presign_options(request)

      presign = generate_presign(location, options, request)

      make_response(presign, request)
    end

    # Uppy client sends an OPTIONS request to fetch information about the
    # Uppy Companion. Since our Rack app is only acting as Uppy Companion, we
    # just return a successful response.
    def handle_options_request(request)
      [200, {}, []]
    end

    # Generates the location using `Shrine#generate_uid`, and extracts the
    # extension from the `filename` query parameter. If `:presign_location`
    # option is given, calls that instead.
    def get_presign_location(request)
      if @presign_location
        @presign_location.call(request)
      else
        extension = File.extname(request.params["filename"].to_s)
        uploader.send(:generate_uid, nil) + extension
      end
    end

    # Calls `:presign_options` option block if given.
    def get_presign_options(request)
      options = @presign_options
      options = options.call(request) if options.respond_to?(:call)
      options || {}
    end

    # Calls `#presign` on the storage, and returns the `url`, `fields`, and
    # `headers` information in a serialializable format. If `:presign`
    # option is given, calls that instead of calling `#presign`.
    def generate_presign(location, options, request)
      if @presign
        data = @presign.call(location, options, request)
      else
        data = storage.presign(location, **options)
      end

      { fields: {}, headers: {} }.merge(data.to_h)
    end

    # Transforms the presign hash into a JSON response. It returns a Rack
    # response triple - an array consisting of a status number, hash of
    # headers, and a body enumerable. If `:rack_response` option is given,
    # calls that instead.
    def make_response(object, request)
      if @rack_response
        response = @rack_response.call(object, request)
      else
        response = [200, { "Content-Type" => CONTENT_TYPE_JSON }, [object.to_json]]
      end

      # prevent browsers from caching the response
      response[1]["Cache-Control"] = "no-store" unless response[1].key?("Cache-Control")

      response
    end

    # Used for early returning an error response.
    def error!(status, message)
      if Rack.release >= "3"
        throw :halt, [status, { "content-type" => CONTENT_TYPE_TEXT }, [message]]
      else
        throw :halt, [status, { "Content-Type" => CONTENT_TYPE_TEXT }, [message]]
      end
    end

    # Returns the uploader around the specified storage.
    def uploader
      @shrine_class.new(@storage_key)
    end

    # Returns the storage object.
    def storage
      @shrine_class.find_storage(@storage_key)
    end
  end
end
