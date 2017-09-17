require "rack"

require "json"

class Shrine
  module Plugins
    # The `presign_endpoint` plugin provides a Rack endpoint which generates
    # the URL, fields, and headers that can be used to upload files directly to
    # a storage service. It can be used with client-side file upload libraries
    # like [FineUploader], [Dropzone] or [jQuery-File-Upload] for asynchronous
    # uploads. Storage services that support direct uploads include [Amazon
    # S3], [Google Cloud Storage], [Microsoft Azure Storage] and more.
    #
    #     plugin :presign_endpoint
    #
    # The plugin adds a `Shrine.presign_endpoint` method which accepts a
    # storage identifier and returns a Rack application that accepts GET
    # requests and generates a presign for the specified storage.
    #
    #     Shrine.presign_endpoint(:cache) # rack app
    #
    # Asynchronous upload is typically meant to replace the caching phase in
    # the default synchronous workflow, so we want to generate parameters for
    # uploads to the temporary (`:cache`) storage.
    #
    # We can mount the returned Rack application inside our application:
    #
    #     Rails.application.routes.draw do
    #       mount Shrine.presign_endpoint(:cache) => "/presign"
    #     end
    #
    # The above will create a `GET /presign` endpoint, which generates presign
    # URL, fields, and headers using the specified storage, and returns it in
    # JSON format.
    #
    #     # GET /presign
    #     {
    #       "url": "https://my-bucket.s3-eu-west-1.amazonaws.com",
    #       "fields": {
    #         "key": "b7d575850ba61b44c8a9ff889dfdb14d88cdc25f8dd121004c8",
    #         "policy": "eyJleHBpcmF0aW9uIjoiMjAxNS0QwMToxMToyOVoiLCJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJzaHJpbmUtdGVzdGluZyJ9LHsia2V5IjoiYjdkNTc1ODUwYmE2MWI0NGU3Y2M4YTliZmY4OGU5ZGZkYjE2NTQ0ZDk4OGNkYzI1ZjhkZDEyMTAwNGM4In0seyJ4LWFtei1jcmVkZW50aWFsIjoiQUtJQUlKRjU1VE1aWlk0NVVUNlEvMjAxNTEwMjQvZXUtd2VzdC0xL3MzL2F3czRfcmVxdWVzdCJ9LHsieC1hbXotYWxnb3JpdGhtIjoiQVdTNC1ITUFDLVNIQTI1NiJ9LHsieC1hbXotZGF0ZSI6IjIwMTUxMDI0VDAwMTEyOVoifV19",
    #         "x-amz-credential": "AKIAIJF55TMZYT6Q/20151024/eu-west-1/s3/aws4_request",
    #         "x-amz-algorithm": "AWS4-HMAC-SHA256",
    #         "x-amz-date": "20151024T001129Z",
    #         "x-amz-signature": "c1eb634f83f96b69bd675f535b3ff15ae184b102fcba51e4db5f4959b4ae26f4"
    #       },
    #       "headers": {}
    #     }
    #
    # This gives the client all the information it needs to make the upload
    # request to the selected file to the storage service. The `url` field is
    # the request URL, `fields` are the required POST parameters, and `headers`
    # are the required request headers.
    #
    # ## Location
    #
    # By default the generated location won't have any file extension, but you
    # can specify one by sending the `filename` query parameter:
    #
    #     GET /presign?filename=nature.jpg
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
    # `:presign_options`:
    #
    #     plugin :presign_endpoint, presign_options: -> (request) do
    #       filename     = request.params["filename"]
    #       extension    = File.extname(filename)
    #       content_type = Rack::Mime.mime_type(extension)
    #
    #       {
    #         content_length_range: 0..(10*1024*1024),                     # limit filesize to 10MB
    #         content_disposition: "attachment; filename=\"#{filename}\"", # download with original filename
    #         content_type:        content_type,                           # set correct content type
    #       }
    #     end
    #
    # ## Presign
    #
    # You can also customize how the presign itself is generated via the
    # `:presign` option:
    #
    #     plugin :presign_endpoint, presign: -> (id, options, request) do
    #       # return an object that responds to #url, #fields, and #headers
    #     end
    #
    # ## Response
    #
    # The response returned by the endpoint can be customized via the
    # `:rack_response` option:
    #
    #     plugin :presign_endpoint, rack_response: -> (hash, request) do
    #       body = { endpoint: hash[:url], params: hash[:fields], headers: hash[:headers] }.to_json
    #       [201, { "Content-Type" => "application/json" }, [body]]
    #     end
    #
    # ## Ad-hoc options
    #
    # You can override any of the options above when creating the endpoint:
    #
    #     Shrine.presign_endpoint(:cache, presign_location: "${filename}")
    #
    # [FineUploader]: https://github.com/FineUploader/fine-uploader
    # [Dropzone]: https://github.com/enyo/dropzone
    # [jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
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
            presign = @presign.call(location, options, request)
          else
            presign = storage.presign(location, options)
          end

          url     = presign.url
          fields  = presign.fields
          headers = presign.headers if presign.respond_to?(:headers)

          { url: url, fields: fields.to_h, headers: headers.to_h }
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
