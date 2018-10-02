# frozen_string_literal: true

require "rack"

require "json"

class Shrine
  module Plugins
    # The `presign_endpoint` plugin provides a Rack endpoint which generates
    # the URL, fields, and headers that can be used to upload files directly to
    # a storage service. On the client side it's recommended to use [Uppy] for
    # asynchronous uploads. Storage services that support direct uploads
    # include [Amazon S3], [Google Cloud Storage], [Microsoft Azure Storage]
    # and more.
    #
    #     plugin :presign_endpoint
    #
    # The plugin adds a `Shrine.presign_endpoint` method which, given a storage
    # identifier, returns a Rack application that accepts GET requests and
    # generates a presign for the specified storage. You can run this Rack
    # application inside your app:
    #
    #     # config.ru (Rack)
    #     map "/images/presign" do
    #       run ImageUploader.presign_endpoint(:cache)
    #     end
    #
    #     # OR
    #
    #     # config/routes.rb (Rails)
    #     Rails.application.routes.draw do
    #       mount ImageUploader.presign_endpoint(:cache) => "/images/presign"
    #     end
    #
    # Asynchronous upload is typically meant to replace the caching phase in
    # the default synchronous workflow, so we want to generate parameters for
    # uploads to the temporary (`:cache`) storage.
    #
    # The above will create a `GET /images/presign` endpoint, which calls
    # `#presign` on the storage and returns the HTTP verb, URL, params, and
    # headers needed for a single upload directly to the storage service, in
    # JSON format.
    #
    #     # GET /images/presign
    #     {
    #       "method": "post",
    #       "url": "https://my-bucket.s3-eu-west-1.amazonaws.com",
    #       "fields": {
    #         "key": "b7d575850ba61b44c8a9ff889dfdb14d88cdc25f8dd121004c8",
    #         "policy": "eyJleHBpcmF0aW9uIjoiMjAxNS0QwMToxMToyOVoiLCJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJ...",
    #         "x-amz-credential": "AKIAIJF55TMZYT6Q/20151024/eu-west-1/s3/aws4_request",
    #         "x-amz-algorithm": "AWS4-HMAC-SHA256",
    #         "x-amz-date": "20151024T001129Z",
    #         "x-amz-signature": "c1eb634f83f96b69bd675f535b3ff15ae184b102fcba51e4db5f4959b4ae26f4"
    #       },
    #       "headers": {}
    #     }
    #
    # ## Location
    #
    # By default the generated location won't have any file extension, but you
    # can specify one by sending the `filename` query parameter:
    #
    #     # GET /images/presign?filename=nature.jpg
    #
    # It's also possible to customize how the presign location is generated:
    #
    #     plugin :presign_endpoint, presign_location: -> (request) do
    #       "#{SecureRandom.hex}/#{request.params["filename"]}"
    #     end
    #
    # ## Options
    #
    # Some storages accept additional presign options, which you can pass in via
    # `:presign_options`, here is an example for S3 storage:
    #
    #     plugin :presign_endpoint, presign_options: -> (request) do
    #       filename     = request.params["filename"]
    #       type         = request.params["type"]
    #
    #       {
    #         content_length_range: 0..(10*1024*1024),                     # limit filesize to 10MB
    #         content_disposition: "attachment; filename=\"#{filename}\"", # download with original filename
    #         content_type:        type,                                   # set correct content type
    #       }
    #     end
    #
    # The `:presign_options` can be a Proc or a Hash.
    #
    # ## Presign
    #
    # You can also customize how the presign itself is generated via the
    # `:presign` option:
    #
    #     plugin :presign_endpoint, presign: -> (id, options, request) do
    #       # return a Hash with :url, :fields, and :headers keys
    #     end
    #
    # ## Response
    #
    # The response returned by the endpoint can be customized via the
    # `:rack_response` option:
    #
    #     plugin :presign_endpoint, rack_response: -> (data, request) do
    #       body = { endpoint: data[:url], params: data[:fields], headers: data[:headers] }.to_json
    #       [201, { "Content-Type" => "application/json" }, [body]]
    #     end
    #
    # ## Ad-hoc options
    #
    # You can override any of the options above when creating the endpoint:
    #
    #     Shrine.presign_endpoint(:cache, presign_location: "${filename}")
    #
    # [Uppy]: https://uppy.io
    # [Amazon S3]: https://aws.amazon.com/s3/
    # [Google Cloud Storage]: https://cloud.google.com/storage/
    # [Microsoft Azure Storage]: https://azure.microsoft.com/en-us/services/storage/
    module PresignEndpoint
      def self.configure(uploader, opts = {})
        uploader.opts[:presign_endpoint_presign_location] = opts.fetch(:presign_location, uploader.opts[:presign_endpoint_presign_location])
        uploader.opts[:presign_endpoint_presign_options] = opts.fetch(:presign_options, uploader.opts[:presign_endpoint_presign_options])
        uploader.opts[:presign_endpoint_presign] = opts.fetch(:presign, uploader.opts[:presign_endpoint_presign])
        uploader.opts[:presign_endpoint_rack_response] = opts.fetch(:rack_response, uploader.opts[:presign_endpoint_rack_response])
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
          App.new({
            shrine_class:     self,
            storage_key:      storage_key,
            presign_location: opts[:presign_endpoint_presign_location],
            presign_options:  opts[:presign_endpoint_presign_options],
            presign:          opts[:presign_endpoint_presign],
            rack_response:    opts[:presign_endpoint_rack_response],
          }.merge(options))
        end
      end

      # Rack application that accepts GET request to the root URL, calls
      # `#presign` on the specified storage, and returns that information in
      # JSON format.
      class App
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
            error!(405, "Method Not Allowed") unless request.get?

            handle_request(request)
          end

          headers["Content-Length"] = body.map(&:bytesize).inject(0, :+).to_s

          [status, headers, body]
        end

        private

        # Accepts a `Rack::Request` object, generates the presign, and returns a
        # Rack response.
        def handle_request(request)
          location = get_presign_location(request)
          options  = get_presign_options(request)

          presign = generate_presign(location, options, request)

          make_response(presign, request)
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
            data = storage.presign(location, options)
          end

          if data.respond_to?(:to_h)
            { fields: {}, headers: {} }.merge(data.to_h)
          else
            Shrine.deprecation("Returning a custom object in Storage#presign is deprecated, presign_endpoint will not support it in Shrine 3. Storage#presign should return a Hash instead.")

            url     = data.url
            fields  = data.fields
            headers = data.headers if data.respond_to?(:headers)

            { url: url, fields: fields.to_h, headers: headers.to_h }
          end
        end

        # Transforms the presign hash into a JSON response. It returns a Rack
        # response triple - an array consisting of a status number, hash of
        # headers, and a body enumerable. If `:rack_response` option is given,
        # calls that instead.
        def make_response(object, request)
          if @rack_response
            response = @rack_response.call(object, request)
          else
            response = [200, {"Content-Type" => "application/json"}, [object.to_json]]
          end

          # prevent browsers from caching the response
          response[1]["Cache-Control"] = "no-store" unless response[1].key?("Cache-Control")

          response
        end

        # Used for early returning an error response.
        def error!(status, message)
          throw :halt, [status, {"Content-Type" => "text/plain"}, [message]]
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

    register_plugin(:presign_endpoint, PresignEndpoint)
  end
end
