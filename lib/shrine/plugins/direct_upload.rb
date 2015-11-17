require "roda"

require "json"
require "securerandom"

class Shrine
  module Plugins
    # The direct_upload plugin provides a Rack endpoint (implemented in [Roda])
    # which you can use to implement AJAX uploads.
    #
    #     plugin :direct_upload, max_size: 20*1024*1024
    #
    # This is how you could mount the endpoint in a Rails application:
    #
    #     Rails.application.routes.draw do
    #       # adds `POST /attachments/images/:storage/:name`
    #       mount ImageUploader.direct_endpoint => "/attachments/images"
    #     end
    #
    # Note that you should mount a separate endpoint for each uploader that you
    # want to use it with. This now gives your Ruby application a
    # `POST /attachments/images/:storage/:name` route, which accepts a "file"
    # query parameter:
    #
    #     $ curl -F "file=@/path/to/avatar.jpg" localhost:3000/attachments/images/cache/avatar
    #     # {"id":"43kewit94.jpg","storage":"cache","metadata":{...}}
    #
    # The endpoint returns all responses in JSON format. There are many great
    # JavaScript libraries for AJAX file uploads, so for example if we have
    # this form:
    #
    #     <%= form_for @user do |f| %>
    #       <%= f.hidden_field :avatar, value: @user.avatar_data %>
    #       <%= f.file_field :avatar %>
    #     <% end %>
    #
    # this is how we could hook up [jQuery-File-Upload] to our direct upload
    # endpoint:
    #
    #     $('[type="file"]').fileupload({
    #       url: '/attachments/images/cache/avatar',
    #       paramName: 'file',
    #       done: function(e, data) { $(this).prev().value(data.result) }
    #     });
    #
    # Now whenever a file gets chosen, the upload will automatically start in
    # the background. It's typically good to show a progress bar to the user,
    # which jQuery-File-Upload [supports]. After the upload has finished, the
    # uploaded file JSON is written to the hidden field, and will be sent on
    # form submit.
    #
    # ## Presigned
    #
    # An alternative to the direct endpoint is doing direct uploads to the
    # underlying storage. These uploads usually requires extra information
    # from the server, and this plugin can provide an endpoint to it, which
    # you can enable by passing in `presign: true`:
    #
    #     plugin :direct_upload, presign: true
    #
    # This will disable the default `POST /:storage/:name` route (for security
    # reasons), and enable `GET /:storage/presign`. The response for that
    # request looks something like this:
    #
    #     {
    #       "url" => "https://shrine-testing.s3-eu-west-1.amazonaws.com",
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
    # generated randomly. `GET /:storage/presign` accepts additional parameters:
    #
    # :extension
    # : The extension of the file being uploaded (e.g ".jpg").
    #
    # :content_type
    # : Sets the Content-Type header for the uploaded file on S3.
    #
    # Example:
    #
    #     GET /cache/presign?content_type=image/jpeg
    #     GET /cache/presign?extension=.png
    #
    # ## Constraints
    #
    # Note that the direct upload doesn't run validations, they are only run
    # when attached to the record. If you want to limit the MIME type of files,
    # you could add an ["accept" attribute] to your file field. You could also
    # add client side validations for the maximum file size.
    #
    # It's encouraged that you set the `:max_size` option for the endpoint.
    # Once set, when a file that is too big is uploaded, the endpoint will
    # automatically delete the file and return a 413 response. This option
    # also works with presigned uploads, where S3 will reject files that are
    # too big.
    #
    # ## Allowed storages
    #
    # While Shrine only accepts cached attachments on form submits (for security
    # reasons), you can use this endpoint to upload files to any storage, just
    # add it do allowed storages:
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
    #         mount ImageUploader.direct_endpoint => "/attachments/images"
    #       end
    #     end
    #
    # [Roda]: https://github.com/jeremyevans/roda
    # [jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
    # [supports]: https://github.com/blueimp/jQuery-File-Upload/wiki/Options#progress
    # ["accept" attribute]: https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input#attr-accept
    module DirectUpload
      def self.load_dependencies(uploader, *)
        uploader.plugin :rack_file
      end

      def self.configure(uploader, allowed_storages: [:cache], max_size: nil, presign: nil)
        uploader.opts[:direct_upload_allowed_storages] = allowed_storages
        uploader.opts[:direct_upload_max_size] = max_size
        uploader.opts[:direct_upload_presign] = presign
      end

      module ClassMethods
        # Return the cached Roda endpoint.
        def direct_endpoint
          @direct_endpoint ||= build_direct_endpoint
        end

        private

        # Builds the endpoint and assigns it the current Shrine class.
        def build_direct_endpoint
          app = Class.new(App)
          app.opts[:shrine_class] = self
          app.app
        end
      end

      class App < Roda
        plugin :default_headers, "Content-Type"=>"application/json"
        plugin :halt

        # Routes incoming requests. We first check if the storage is allowed,
        # then proceed further with the upload, returning the uploaded file
        # as JSON.
        route do |r|
          r.on ":storage" do |storage_key|
            allow_storage!(storage_key)
            @uploader = shrine_class.new(storage_key.to_sym)

            unless presign?
              r.post ":name" do |name|
                file = get_file
                context = {name: name, phase: :cache}

                json @uploader.upload(file, context)
              end
            else
              r.get "presign" do
                location = SecureRandom.hex(30).to_s + r.params["extension"].to_s
                options = {}
                options[:content_length_range] = 0..max_size if max_size
                options[:content_type] = r.params["content_type"] if r.params["content_type"]

                signature = @uploader.storage.presign(location, options)

                json Hash[url: signature.url, fields: signature.fields]
              end
            end
          end
        end

        def json(object)
          object.to_json
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
          request.halt status, {error: message}.to_json
        end

        def shrine_class
          opts[:shrine_class]
        end

        def allowed_storages
          shrine_class.opts[:direct_upload_allowed_storages]
        end

        def max_size
          shrine_class.opts[:direct_upload_max_size]
        end

        def presign?
          shrine_class.opts[:direct_upload_presign]
        end
      end
    end

    register_plugin(:direct_upload, DirectUpload)
  end
end
