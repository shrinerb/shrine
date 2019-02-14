# frozen_string_literal: true

Shrine.deprecation("The direct_upload plugin has been deprecated in favor of upload_endpoint and presign_endpoint plugins. The direct_upload plugin will be removed in Shrine 3.")

require "roda"
require "json"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/direct_upload.md] on GitHub.
    #
    # [doc/plugins/direct_upload.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/direct_upload.md
    module DirectUpload
      def self.load_dependencies(uploader, *)
        uploader.plugin :rack_file
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:direct_upload_allowed_storages] = opts.fetch(:allowed_storages, uploader.opts.fetch(:direct_upload_allowed_storages, [:cache]))
        uploader.opts[:direct_upload_presign_options] = opts.fetch(:presign_options, uploader.opts.fetch(:direct_upload_presign_options, {}))
        uploader.opts[:direct_upload_presign_location] = opts.fetch(:presign_location, uploader.opts[:direct_upload_presign_location])
        uploader.opts[:direct_upload_max_size] = opts.fetch(:max_size, uploader.opts[:direct_upload_max_size])

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
      end

      # Routes incoming requests. It first asserts that the storage is existent
      # and allowed, then the filesize isn't too large. Afterwards it proceeds
      # with the file upload and returns the uploaded file as JSON.
      class App < Roda
        plugin :default_headers, "Content-Type"=>"application/json"
        plugin :placeholder_string_matchers if Gem::Version.new(Roda::RodaVersion) >= Gem::Version.new("3.0.0")

        route do |r|
          r.on ":storage" do |storage_key|
            @uploader = get_uploader(storage_key)

            r.post ["upload", ":name"] do |name|
              file = get_file
              context = get_context(name)

              uploaded_file = upload(file, context)

              json uploaded_file
            end

            r.get "presign" do
              location = get_presign_location
              options = get_presign_options

              presign_data = generate_presign(location, options)
              response.headers["Cache-Control"] = "no-store"

              json presign_data
            end
          end
        end

        private

        attr_reader :uploader

        # Instantiates the uploader, checking first if the storage is allowed.
        def get_uploader(storage_key)
          allow_storage!(storage_key)
          shrine_class.new(storage_key.to_sym)
        end

        # Retrieves the context for the upload.
        def get_context(name)
          context = {action: :cache, phase: :cache}

          if name != "upload"
            Shrine.deprecation("The \"POST /:storage/:name\" route of the direct_upload plugin is deprecated, and it will be removed in Shrine 3. Use \"POST /:storage/upload\" instead.")
            context[:name] = name
          end

          unless presign_storage?
            context[:location] = request.params["key"]
          end

          context
        end

        # Uploads the file to the requested storage.
        def upload(file, context)
          uploader.upload(file, context)
        end

        # Generates a unique location, or calls `:presign_location`.
        def get_presign_location
          if presign_location
            presign_location.call(request)
          else
            extension = request.params["extension"]
            extension.prepend(".") if extension && !extension.start_with?(".")
            uploader.send(:generate_uid, nil) + extension.to_s
          end
        end

        # Returns dynamic options for generating the presign.
        def get_presign_options
          options = presign_options
          options = options.call(request) if options.respond_to?(:call)
          options || {}
        end

        # Generates the presign hash for the request.
        def generate_presign(location, options)
          if presign_storage?
            generate_real_presign(location, options)
          else
            generate_fake_presign(location, options)
          end
        end

        # Generates a presign by calling the storage.
        def generate_real_presign(location, options)
          signature = uploader.storage.presign(location, options)
          {url: signature.url, fields: signature.fields}
        end

        # Generates a presign that points to the direct upload endpoint.
        def generate_fake_presign(location, options)
          url = request.url.sub(/presign[^\/]*$/, "upload")
          {url: url, fields: {key: location}}
        end

        # Returns true if the storage supports presigns.
        def presign_storage?
          uploader.storage.respond_to?(:presign)
        end

        # Halts the request if storage is not allowed.
        def allow_storage!(storage_key)
          if !allowed_storages.map(&:to_s).include?(storage_key)
            error! 403, "Storage #{storage_key.inspect} is not allowed."
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

        def presign_options
          shrine_class.opts[:direct_upload_presign_options]
        end

        def presign_location
          shrine_class.opts[:direct_upload_presign_location]
        end

        def max_size
          shrine_class.opts[:direct_upload_max_size]
        end
      end
    end

    register_plugin(:direct_upload, DirectUpload)
  end
end
