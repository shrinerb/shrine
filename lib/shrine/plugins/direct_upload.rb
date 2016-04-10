require "roda"

require "json"
require "securerandom"

class Shrine
  module Plugins
    # The direct_upload plugin provides a [Roda] endpoint which can be used for
    # uploading individual files asynchronously.
    #
    #     plugin :direct_upload
    #
    # This is how you could mount the endpoint in a Rails application:
    #
    #     Rails.application.routes.draw do
    #       mount ImageUploader::UploadEndpoint => "/attachments/images"
    #     end
    #
    # You should always mount a new endpoint for each uploader that you want to
    # enable direct uploads for. This now gives your Ruby application a `POST
    # /attachments/images/:storage/upload` route, which accepts a "file" query
    # parameter, and returns the uploaded file in JSON format:
    #
    #     # POST /attachments/images/cache/upload (file upload)
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
    # Once you've uploaded the file, you need to assign the result to the
    # hidden attachment field in the form. There are many great JavaScript
    # libraries for file uploads, most popular being [jQuery-File-Upload].
    #
    # ## Limiting filesize
    #
    # It's good idea to limit the maximum filesize of uploaded files, if you
    # set the `:max_size` option, files which are too big will get
    # automatically deleted and 413 status will be returned:
    #
    #     plugin :direct_upload, max_size: 5*1024*1024 # 5 MB
    #
    # Note that this option doesn't affect presigned uploads, but there you can
    # limit the filesize with storage options.
    #
    # ## Presigning
    #
    # An alternative to the direct endpoint is uploading directly to the
    # underlying storage (S3). These uploads usually require extra information
    # from the server, you can enable that route by passing `presign: true`:
    #
    #     plugin :direct_upload, presign: true
    #
    # This will add `GET /:storage/presign`, and disable the default `POST
    # /:storage/:name` (for security reasons) The response for that request
    # looks something like this:
    #
    #     {
    #       "url" => "https://my-bucket.s3-eu-west-1.amazonaws.com",
    #       "fields" => {
    #         "key" => "b7d575850ba61b44c8a9ff889dfdb14d88cdc25f8dd121004c8",
    #         "policy" => "eyJleHBpcmF0aW9uIjoiMjAxNS0QwMToxMToyOVoiLCJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJzaHJpbmUtdGVzdGluZyJ9LHsia2V5IjoiYjdkNTc1ODUwYmE2MWI0NGU3Y2M4YTliZmY4OGU5ZGZkYjE2NTQ0ZDk4OGNkYzI1ZjhkZDEyMTAwNGM4In0seyJ4LWFtei1jcmVkZW50aWFsIjoiQUtJQUlKRjU1VE1aWlk0NVVUNlEvMjAxNTEwMjQvZXUtd2VzdC0xL3MzL2F3czRfcmVxdWVzdCJ9LHsieC1hbXotYWxnb3JpdGhtIjoiQVdTNC1ITUFDLVNIQTI1NiJ9LHsieC1hbXotZGF0ZSI6IjIwMTUxMDI0VDAwMTEyOVoifV19",
    #         "x-amz-credential" => "AKIAIJF55TMZYT6Q/20151024/eu-west-1/s3/aws4_request",
    #         "x-amz-algorithm" => "AWS4-HMAC-SHA256",
    #         "x-amz-date" => "20151024T001129Z",
    #         "x-amz-signature" => "c1eb634f83f96b69bd675f535b3ff15ae184b102fcba51e4db5f4959b4ae26f4"
    #       }
    #     }
    #
    # The `url` is where the file needs to be uploaded to, and `fields` is
    # additional data that needs to be send on the upload. The `fields.key`
    # attribute is the location where the file will be uploaded to, it is
    # generated randomly without an extension, but you can add it:
    #
    #     GET /cache/presign?extension=.png
    #
    # If you want additional options to be passed to Storage::S3#presign, you
    # can pass a block to `:presign`, and it will yield Roda's request object:
    #
    #     plugin :direct_upload, presign: ->(request) do
    #       {
    #         content_length_range: 0..(5*1024*1024), # limit the filesize to 5 MB
    #         content_type: request.params["content_type"], # use "content_type" query parameter
    #       }
    #     end
    #
    # See the [Direct Uploads to S3] guide for further instructions on how to
    # hook this up in a form.
    #
    # ## Allowed storages
    #
    # While Shrine only accepts cached attachments on form submits (for security
    # reasons), you can use this endpoint to upload files to any storage, just
    # add it to allowed storages:
    #
    #     plugin :direct_upload, allowed_storages: [:cache, :store]
    #
    # ## Authentication
    #
    # If you want to authenticate the endpoint, you should be able to do it
    # easily if your web framework has a good enough router. For example, in
    # Rails you could add a `constraints` directive:
    #
    #     Rails.application.routes.draw do
    #       constraints(->(r){r.env["warden"].authenticate!}) do
    #         mount ImageUploader::UploadEndpoint => "/attachments/images"
    #       end
    #     end
    #
    # ## Customizing endpoint
    #
    # Since the endpoint is a [Roda] app, it can be easily customized via
    # plugins:
    #
    #     class MyUploader
    #       class UploadEndpoint
    #         plugin :hooks
    #
    #         after do |response|
    #           # ...
    #         end
    #       end
    #     end
    #
    # Upon subclassing uploader the upload endpoint is also subclassed. You can
    # also call the plugin again in an uploader subclass to change its
    # configuration.
    #
    # [Roda]: https://github.com/jeremyevans/roda
    # [jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
    # [supports]: https://github.com/blueimp/jQuery-File-Upload/wiki/Options#progress
    # ["accept" attribute]: https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input#attr-accept
    # [`Roda::RodaRequest`]: http://roda.jeremyevans.net/rdoc/classes/Roda/RodaPlugins/Base/RequestMethods.html
    # [Direct Uploads to S3]: http://shrinerb.com/rdoc/files/doc/direct_s3_md.html
    module DirectUpload
      def self.load_dependencies(uploader, *)
        uploader.plugin :rack_file
      end

      def self.configure(uploader, allowed_storages: [:cache], presign: nil, max_size: nil)
        uploader.opts[:direct_upload_allowed_storages] = allowed_storages
        uploader.opts[:direct_upload_presign] = presign
        uploader.opts[:direct_upload_max_size] = max_size

        uploader.assign_upload_endpoint(App) unless uploader.const_defined?(:UploadEndpoint)
      end

      module ClassMethods
        # Assigns the subclass a copy of the upload endpoint class.
        def inherited(subclass)
          super
          subclass.assign_upload_endpoint(self::UploadEndpoint)
        end

        # Assigns the subclassed endpoint as the `UploadEndpoint` constant.
        def assign_upload_endpoint(klass)
          endpoint_class = Class.new(klass)
          endpoint_class.opts[:shrine_class] = self
          const_set(:UploadEndpoint, endpoint_class)
        end

        # Returns the Roda direct upload endpoint.
        def direct_endpoint
          warn "Shrine.direct_endpoint is deprecated and will be removed in Shrine 2, you should use Shrine::UploadEndpoint instead."
          self::UploadEndpoint
        end
      end

      # Routes incoming requests. It first asserts that the storage is existent
      # and allowed, then the filesize isn't too large. Afterwards it proceeds
      # with the file upload and returns the uploaded file as JSON.
      class App < Roda
        plugin :default_headers, "Content-Type"=>"application/json"

        route do |r|
          r.on ":storage" do |storage_key|
            @uploader = get_uploader(storage_key)

            r.post ["upload", ":name"] do |name|
              file = get_file
              context = get_context(name)

              uploaded_file = upload(file, context)

              json uploaded_file
            end unless presign

            r.get "presign" do
              location = generate_location
              options = presign_options

              signature = generate_presign(location, options)

              json Hash[url: signature.url, fields: signature.fields]
            end if presign
          end
        end

        private

        # Instantiates the uploader, checking first if the storage is allowed.
        def get_uploader(storage_key)
          allow_storage!(storage_key)
          shrine_class.new(storage_key.to_sym)
        end

        # Retrieves the context for the upload.
        def get_context(name)
          context = {phase: :cache}
          if name != "upload"
            warn "The \"POST /:storage/:name\" route of the direct_upload Shrine plugin is deprecated, and it will be removed in Shrine 3. Use \"POST /:storage/upload\" instead."
            context[:name] = name
          end
          context
        end

        # Uploads the file to the requested storage.
        def upload(file, context)
          @uploader.upload(file, context)
        end

        # Generates a unique location.
        def generate_location
          SecureRandom.hex(30) + request.params["extension"].to_s
        end

        # Returns dynamic options for generating the presign.
        def presign_options
          options = presign.call(request) if presign.respond_to?(:call)
          options || {}
        end

        # Calls storage to generate a presign.
        def generate_presign(location, options)
          @uploader.storage.presign(location, options)
        end

        # Halts the request if storage is not allowed.
        def allow_storage!(storage)
          if !allowed_storages.map(&:to_s).include?(storage)
            error! 403, "Storage #{storage.inspect} is not allowed."
          end
        end

        # Returns the Rack file wrapped in an IO-like object. If "file" is
        # missing or is too big, the request is halted.
        def get_file
          file = require_param!("file")
          error! 400, "The \"file\" query parameter is not a file." if !(file.is_a?(Hash) && file.key?(:tempfile))
          check_filesize!(file[:tempfile]) if max_size

          RackFile::UploadedFile.new(file)
        end

        # If the file is too big, deletes the file and halts the request.
        def check_filesize!(file)
          if file.size > max_size
            file.delete
            megabytes = max_size.to_f / 1024 / 1024
            error! 413, "The file is too big (maximum size is #{megabytes} MB)."
          end
        end

        # Loudly requires the param.
        def require_param!(name)
          request.params.fetch(name)
        rescue KeyError
          error! 400, "Missing query parameter: #{name.inspect}"
        end

        # Halts the request with the error message.
        def error!(status, message)
          response.status = status
          response.write({error: message}.to_json)
          request.halt
        end

        def json(object)
          object.to_json
        end

        def shrine_class
          opts[:shrine_class]
        end

        def allowed_storages
          shrine_class.opts[:direct_upload_allowed_storages]
        end

        def presign
          shrine_class.opts[:direct_upload_presign]
        end

        def max_size
          shrine_class.opts[:direct_upload_max_size]
        end
      end
    end

    register_plugin(:direct_upload, DirectUpload)
  end
end
