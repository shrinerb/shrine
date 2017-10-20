# frozen_string_literal: true

require "rack"

require "json"

class Shrine
  module Plugins
    # The `upload_endpoint` plugin provides a Rack endpoint which accepts file
    # uploads and forwards them to specified storage. It can be used with
    # client-side file upload libraries like [FineUploader], [Dropzone] or
    # [jQuery-File-Upload] for asynchronous uploads.
    #
    #     plugin :upload_endpoint
    #
    # The plugin adds a `Shrine.upload_endpoint` method which, given a storage
    # identifier, returns a Rack application that accepts multipart POST
    # requests, and uploads received files to the specified storage. You can
    # run this Rack application inside your app:
    #
    #     # config.ru (Rack)
    #     map "/images/upload" do
    #       run ImageUploader.upload_endpoint(:cache)
    #     end
    #
    #     # OR
    #
    #     # config/routes.rb (Rails)
    #     Rails.application.routes.draw do
    #       mount ImageUploader.upload_endpoint(:cache) => "/images/upload"
    #     end
    #
    # Asynchronous upload is typically meant to replace the caching phase in
    # the default synchronous workflow, so we want the uploads to go to
    # temporary (`:cache`) storage.
    #
    # The above will create a `POST /images/upload` endpoint, which uploads the
    # file received in the `file` param using `ImageUploader`, and returns a
    # JSON representation of the uploaded file.
    #
    #     # POST /images/upload
    #     {
    #       "id": "43kewit94.jpg",
    #       "storage": "cache",
    #       "metadata": {
    #         "size": 384393,
    #         "filename": "nature.jpg",
    #         "mime_type": "image/jpeg"
    #       }
    #     }
    #
    # This JSON string can now be assigned to an attachment attribute instead
    # of a raw file. In a form it can be written to a hidden attachment field,
    # and then it can be assigned as the attachment.
    #
    # ## Limiting filesize
    #
    # It's good practice to limit the accepted filesize of uploaded files. You
    # can do that with the `:max_size` option:
    #
    #     plugin :upload_endpoint, max_size: 20*1024*1024 # 20 MB
    #
    # If the uploaded file is larger than the specified value, a `413 Payload
    # Too Large` response will be returned.
    #
    # ## Context
    #
    # The upload context will *not* contain `:record` and `:name` values, as
    # the upload happens independently of a database record. The endpoint will
    # sent the following upload context:
    #
    # * `:action` - holds the value `:upload`
    # * `:request` - holds an instance of `Rack::Request`
    #
    # You can update the upload context via `:upload_context`:
    #
    #     plugin :upload_endpoint, upload_context: -> (request) do
    #       { location: "my-location" }
    #     end
    #
    # ## Upload
    #
    # You can also customize the upload itself via the `:upload` option:
    #
    #     plugin :upload_endpoint, upload: -> (io, context, request) do
    #       # perform uploading and return the Shrine::UploadedFile
    #     end
    #
    # ## Response
    #
    # The response returned by the endpoint can be customized via the
    # `:rack_response` option:
    #
    #     plugin :upload_endpoint, rack_response: -> (uploaded_file, request) do
    #       body = { data: uploaded_file.data, url: uploaded_file.url }.to_json
    #       [201, { "Content-Type" => "application/json" }, [body]]
    #     end
    #
    # ## Ad-hoc options
    #
    # You can override any of the options above when creating the endpoint:
    #
    #     Shrine.upload_endpoint(:cache, max_size: 20*1024*1024)
    #
    # [FineUploader]: https://github.com/FineUploader/fine-uploader
    # [Dropzone]: https://github.com/enyo/dropzone
    # [jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
    module UploadEndpoint
      def self.load_dependencies(uploader, opts = {})
        uploader.plugin :rack_file
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:upload_endpoint_max_size] = opts.fetch(:max_size, uploader.opts[:upload_endpoint_max_size])
        uploader.opts[:upload_endpoint_upload_context] = opts.fetch(:upload_context, uploader.opts[:upload_endpoint_upload_context])
        uploader.opts[:upload_endpoint_upload] = opts.fetch(:upload, uploader.opts[:upload_endpoint_upload])
        uploader.opts[:upload_endpoint_rack_response] = opts.fetch(:rack_response, uploader.opts[:upload_endpoint_rack_response])
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
          App.new({
            shrine_class:   self,
            storage_key:    storage_key,
            max_size:       opts[:upload_endpoint_max_size],
            upload_context: opts[:upload_endpoint_upload_context],
            upload:         opts[:upload_endpoint_upload],
            rack_response:  opts[:upload_endpoint_rack_response],
          }.merge(options))
        end
      end

      # Rack application that accepts multipart POSt request to the root URL,
      # calls `#upload` with the uploaded file, and returns the uploaded file
      # information in JSON format.
      class App
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

          headers["Content-Length"] = body.map(&:bytesize).inject(0, :+).to_s

          [status, headers, body]
        end

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

          error!(400, "Upload Not Found") unless file.is_a?(Hash) && file[:tempfile]
          error!(413, "Upload Too Large") if @max_size && file[:tempfile].size > @max_size

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
            [200, {"Content-Type" => "application/json"}, [object.to_json]]
          end
        end

        # Used for early returning an error response.
        def error!(status, message)
          throw :halt, [status, {"Content-Type" => "text/plain"}, [message]]
        end

        # Returns the uploader around the specified storage.
        def uploader
          @shrine_class.new(@storage_key)
        end
      end
    end

    register_plugin(:upload_endpoint, UploadEndpoint)
  end
end
