# frozen_string_literal: true

require "rack"
require "content_disposition"

require "openssl"

class Shrine
  module Plugins
    # The `derivation_endpoint` plugin provides a Rack app for dynamically
    # processing uploaded files on request. This allows you to create URLs to
    # files that haven't been processed yet, and have the endpoint process them
    # on-the-fly.
    #
    # ## Usage
    #
    # When loading the plugin, you need to provide a secret key, which will be
    # used to sign URLs. We also need to provide a path prefix where the
    # endpoint will be mounted, which will be added to generated URLs.
    #
    #     class ImageUploader < Shrine
    #       plugin :derivation_endpoint,
    #         secret_key: "<your-secret-key>",
    #         prefix:     "deriatives/image"
    #     end
    #
    # ### Mounting endpoint
    #
    # We can then mount an endpoint for a specific uploader into our app's
    # router on the specified path prefix:
    #
    #     # config.ru (Rack)
    #     map "/derivations/image" do
    #       run ImageUploader.derivation_endpoint
    #     end
    #
    #     # OR
    #
    #     # config/routes.rb (Rails)
    #     Rails.application.routes.draw do
    #       mount ImageUploader.derivation_endpoint => "/derivations/image"
    #     end
    #
    # ### Defining derivations
    #
    # Now that the endpoint is set up, we can define derivations on our
    # uploader. Derivations are defined with a name and a block:
    #
    #     class ImageUploader < Shrine
    #       derivation :thumbnail do |file, *args|
    #         # ...
    #       end
    #     end
    #
    # The name uniquely identifies the derivation, and will be used when
    # generating URLs. The block is called whenever the derivation endpoint
    # receives a request for that derivation. The first argument is the
    # original uploaded file downloaded to disk, and the rest are the arguments
    # for the derivation provided when generating the URL. The block *must*
    # return a file object, and that will be returned in the response.
    #
    # Let's use the [ImageProcessing] gem to generate some thumbnails:
    #
    #     require "image_processing/mini_magick"
    #
    #     class ImageUploader < Shrine
    #       derivation :thumbnail do |file, width, height|
    #         ImageProcessing::MiniMagick
    #           .source(file)
    #           .resize_to_limit!(width.to_i, height.to_i)
    #       end
    #     end
    #
    # ### Generating URLs
    #
    # Now we can call `#derivation_url` on an uploaded file to generate a URL
    # for a specific thumbnail:
    #
    #     photo.image.derivation_url(:thumbnail, "500", "400")
    #     #=> "/derivations/image/thumbnail/500/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
    #
    # The first argument is the derivation name, while the rest are arguments
    # that will be passed to the derivation block. They are included in the URL
    # path, along will the serialized uploaded file that will be used as the
    # source file. The URL is signed with the secret key to prevent tampering.
    #
    # The example above assumes that `photo` is an instance of a `Photo` model
    # which defines an `image` attachment. Calling `photo.image` returns an
    # instance of `Shrine::UploadedFile` given that a file has been attached.
    #
    # ### Performance considerations
    #
    # Unless you've enabled `:upload` and `:upload_redirect` options, the
    # derivation endpoint will generate and serve derivatives on each request.
    # This can take a lot of resources, so you want it to happen rarely.
    #
    # Therefore, it's highly recommended to put a **CDN or other HTTP cache**
    # in front of your application. Once you have that, you can have derivation
    # URLs point to the CDN by setting the `:host` option:
    #
    #     plugin :derivation_endpoint, host: "https://your-dist-url.cloudfront.net"
    #
    # You can also set `:upload`, which will make the derivation endpoint cache
    # processed derivatives on the storage, so that processing happens only on
    # initial request. If you also set `:upload_redirect`, the endpoint will
    # redirect to the cached derivative on the storage instead of serving it.
    #
    #     plugin :derivation_endpoint, upload: true
    #
    # These two strategies are not mutually exclusive, you can use both.
    #
    # ## Derivation response
    #
    # There are three ways to generate derivation responses. First is the one
    # we've already seen, which is to plug the Rack app into our router.
    #
    #     # config/routes.rb
    #     Rails.application.routes.draw do
    #       mount ImageUploader.derivation_endpoint => "/derivations/image"
    #     end
    #
    # Second way keeps the URL format, but allows you to route the request to
    # a custom controller. Inside the controller you can call
    # `Shrine.derivation_response` with the Rack env hash to handle the
    # request. The target derivation name and arguments are inferred from
    # the request information. The return value is an array of the status,
    # headers, and body that should be set for the top-level response.
    #
    #     # config/routes.rb
    #     Rails.application.routes.draw do
    #       get "/derivations/image/*rest" => "derivations#image"
    #     end
    #
    #     # app/controllers/derivations_controller.rb
    #     class DerivationsController < ApplicationController
    #       def image
    #         set_rack_response ImageUploader.derivation_response(request.env)
    #       end
    #
    #       private
    #
    #       def set_rack_response((status, headers, body))
    #         self.status = status
    #         self.headers.merge!(headers)
    #         self.response_body = body
    #       end
    #     end
    #
    # This approach gives greater flexibility as it allows executing additional
    # code on the controller level before and after generating a derivation
    # response. This might make operations like authentication easier.
    #
    # The third way allows you to use custom URLs for derivations. In the
    # controller you can call `#derivation_response` directly on the
    # `UploadedFile`, passing the derivation name, arguments, and the Rack env
    # hash.
    #
    #     # config/routes.rb
    #     Rails.application.routes.draw do
    #       resources :photos do
    #         member do
    #           get "thumbnail" # for example
    #         end
    #       end
    #     end
    #
    #     # app/controllers/photos_controller.rb
    #     class PhotosController < ApplicationController
    #       def thubmnail
    #         photo = Photos.find(params[:id])
    #         image = photo.image
    #
    #         set_rack_response image.derivation_response(:thumbnail, 300, 300, env: request.env)
    #       end
    #
    #       private
    #
    #       def set_rack_response((status, headers, body))
    #         self.status = status
    #         self.headers.merge!(headers)
    #         self.response_body = body
    #       end
    #     end
    #
    # This approach for example allows authorizing access to derivatives, as we
    # can access the database record to which the uploaded file belongs to
    # prior to generating a derivation response.
    #
    # The `Shrine.derivation_endpoint`, `Shrine.derivation_response`, and
    # `UploadedFile#derivation_response` all accept additional options, which
    # override any options set on the plugin level.
    #
    #     ImageUploader.derivation_endpoint(disposition: "attachment")
    #     # or
    #     ImageUploader.derivation_response(env, disposition: "attachment")
    #     # or
    #     uploaded_file.derivation_response(:thumbnail, env: env, disposition: "attachment")
    #
    # ## Dynamic options
    #
    # When passing options to the plugin, to `Shrine.derivation_endpoint`,
    # `Shrine.derivation_response`, or to
    # `Shrine::UploadedFile#derivation_response`, for most options the value
    # can be a block that returns a dynamic result. The block will be called
    # with a context hash containing `:name`, `:args`, and `:uploaded_file`.
    #
    #     plugin :derivation_endpoint, disposition: -> (context) do
    #       context[:name]          #=> :thumbnail
    #       context[:args]          #=> ["500", "400"]
    #       context[:uploaded_file] #=> #<Shrine::UploadedFile>
    #
    #       # ...
    #     end
    #
    # For example, we can use it to specify that thumbnails should be rendered
    # inline by the browser, while other derivatives should be downloaded.
    #
    #     plugin :derivation_endpoint, disposition: -> (context) do
    #       if context[:name] == :thumbnail
    #         "inline"
    #       else
    #         "attachment"
    #       end
    #     end
    #
    # ## Host
    #
    # By default generated URLs are relative. To generate absolute URLs, you
    # can pass the `:host` option:
    #
    #     plugin :derivation_endpoint, host: "https://example.com"
    #
    # Now the generated URLs will include the specified URL host:
    #
    #     uploaded_file.derivation_url(:thumbnail)
    #     #=> "https://example.com/thumbnail/eyJpZCI6ImZvbyIsInN?signature=..."
    #
    # You can also pass `:host` per URL:
    #
    #     uploaded_file.derivation_url(:thumbnail, host: "https://example.com")
    #     #=> "https://example.com/thumbnail/eyJpZCI6ImZvbyIsInN?signature=..."
    #
    # ## Prefix
    #
    # If you're mounting the derivation endpoint under a path prefix, the
    # `:prefix` option needs to match in order for correct URLs to be generated:
    #
    #     plugin :derivation_endpoint, prefix: "derivations/image"
    #
    # Now generated URLs will include the specified path prefix:
    #
    #     uploaded_file.derivation_url(:thumbnail)
    #     #=> "/derivations/image/thumbnail/eyJpZCI6ImZvbyIsInN?signature=..."
    #
    # You can also pass `:prefix` per URL:
    #
    #     uploaded_file.derivation_url(:thumbnail, prefix: "derivations/image")
    #     #=> "/derivations/image/thumbnail/eyJpZCI6ImZvbyIsInN?signature=..."
    #
    # ## Expiration
    #
    # By default generated URLs are valid indefinitely. If you want URLs to
    # expire after a certain amount of time, you can set the `:expires_in`
    # option:
    #
    #     plugin :derivation_endpoint, expires_in: 90
    #
    # Now any URL will stop being valid 90 seconds after it was generated:
    #
    #     uploaded_file.derivation_url(:thumbnail)
    #     #=> "/thumbnail/eyJpZCI6ImZvbyIsInN?expires_at=1547843568&signature=..."
    #
    # You can also pass `:expires_in` per URL:
    #
    #     uploaded_file.derivation_url(:thumbnail, expires_in: 90)
    #     #=> "/thumbnail/eyJpZCI6ImZvbyIsInN?expires_at=1547843568&signature=..."
    #
    # ## Content Type
    #
    # By default in the derivation response, the [`Content-Type`] header is
    # inferred from the file extension of the derivative (using `Rack::Mime`).
    # You can override that with the `:type` option:
    #
    #     plugin :derivation_endpoint, type: -> (context) do
    #       "image/webp" if context[:name] == :webp
    #     end
    #
    # If the block returns `nil`, then the default type will be set. You can
    # also set `:type` per URL:
    #
    #     uploaded_file.derivation_url(:webp, type: "image/webp")
    #     #=> "/webp/eyJpZCI6ImZvbyIsInN?type=image%2Fwebp&signature=..."
    #
    # ## Content Disposition
    #
    # By default in the derivation response, the [`Content-Disposition`] header
    # sets the disposition to `inline`, while the download filename is generated
    # from derivation name, arguments and source file id. You can override that
    # with the `:disposition` and `:filename` options:
    #
    #     plugin :derivation_endpoint,
    #       disposition: -> (context) { context[:name] == :thumbnail ? "inline" : "attachment" },
    #       filename:    -> (context) { [context[:name], *context[:args]].join("-") }
    #
    # When the user opens the link in the browser, an `inline` disposition will
    # tell the browser to render the file if possible, while `attachment`
    # disposition will force download.
    #
    # The `:filename` and `:disposition` options can also be set per URL:
    #
    #     uploaded_file.derivation_url(:pdf, disposition: "attachment", filename: "custom-filename")
    #     #=> "/thumbnail/eyJpZCI6ImZvbyIsInN?disposition=attachment&filename=custom-filename&signature=..."
    #
    # ## Uploading
    #
    # By default the derivation from a source file will be called each time
    # it's requested. However, you can cache the derivatives to a storage by
    # setting `:upload` to `true`. On first request the generated derivative
    # will be uploaded to storage, and then on subsequent requests the already
    # uploaded derivative will be served from the storage.
    #
    #     plugin :derivation_endpoint, upload: true
    #
    # The target storage used is the same as for the source uploaded file, but
    # it can be changed via `:upload_storage`:
    #
    #     plugin :derivation_endpoint, upload: true,
    #                                  upload_storage: :thumbnail_storage
    #
    # The derivative will be uploaded to `<source id>/<name>-<args>` by default,
    # and can be changed via `:upload_location`:
    #
    #     plugin :derivation_endpoint, upload: true, upload_location: -> (context) do
    #       # e.g. "derivatives/9a7d1bfdad24a76f9cfaff137fe1b5c7/thumbnail-1000-800"
    #       [
    #         "derivatives",
    #         File.basename(context[:uploaded_file].id, ".*"),
    #         [context[:name], *context[:args]].join("-")
    #       ].join("/")
    #     end
    #
    # Additional storage-specific upload options can be passed via
    # `:upload_options`:
    #
    #     plugin :derivation_endpoint, upload: true,
    #                                  upload_options: { acl: "public-read" }
    #
    # ### Redirecting
    #
    # The derivative content will be served through the endpoint by default.
    # However, you can configure the endpoint to redirect to the uploaded
    # derivative on the storage:
    #
    #     plugin :derivation_endpoint, upload: true,
    #                                  upload_redirect: true
    #
    # In that case additional storage-specific URL options can also be passed in:
    #
    #     plugin :derivation_endpoint, upload: true,
    #                                  upload_redirect: true,
    #                                  upload_redirect_url_options: { public: true }
    #
    # ## Cache busting
    #
    # The derivation endpoint returns `Cache-Control` header in the derivation
    # response telling HTTP caches like CDNs to cache the response for a year.
    # So if you change how a derivation is being performed, users might still
    # see the previous version of the derivative if it was already generated
    # and cached.
    #
    # If you want the already cached derivatives to be re-generated, you can
    # add a "version" parameter to the URL, which will make HTTP caches treat
    # is as a new URL. You can do this by via the `:version` option. You
    # probably want to bump the version only of the derivations that you've
    # changed.
    #
    #     plugin :derivation_endpoint, version: -> (context) do
    #       context[:name] == :thumbnail ? 1 : nil
    #     end
    #
    # Now all `:thumbnail` derivation URLs will include `version` in the query
    # string:
    #
    #     uploaded_file.derivation_url(:thumbnail)
    #     #=> "/thumbnail/eyJpZCI6ImZvbyIsInN?version=1&signature=..."
    #
    # You can also bump the `:version` per URL:
    #
    #     uploaded_file.derivation_url(:thumbnail, version: 1)
    #     #=> "/thumbnail/eyJpZCI6ImZvbyIsInN?version=1&signature=..."
    #
    # ## Accessing uploaded file
    #
    # If you want to access the source `UploadedFile` object when deriving, you
    # can set `:include_uploaded_file` to `true`.
    #
    #     plugin :derivation_endpoint, include_uploaded_file: true
    #
    # Now the source `UploadedFile` will be passed as the second argument of
    # the derivation block:
    #
    #     derivation :thumbnail do |file, uploaded_file, width, height|
    #       uploaded_file             #=> #<Shrine::UploadedFile>
    #       uploaded_file.id          #=> "9a7d1bfdad24a76f9cfaff137fe1b5c7.jpg"
    #       uploaded_file.storage_key #=> "store"
    #       uploaded_file.metadata    #=> {}
    #
    #       # ...
    #     end
    #
    # By default original metadata that was extracted during attachment isn't
    # available, to keep the derivation URL as short as possible. However, if
    # you want to have original metadata available when deriving, you can set
    # the `:metadata` option to the list of needed metadata values:
    #
    #     plugin :derivation_endpoint, metadata: ["filename", "mime_type"]
    #
    # Now `filename` and `mime_type` metadata values will be available in the
    # derivation block:
    #
    #     derivation :thumbnail do |file, uploaded_file, width, height|
    #       uploaded_file.metadata #=>
    #       # {
    #       #  "filename" => "nature.jpg",
    #       #  "mime_type" => "image/jpeg"
    #       # }
    #
    #       uploaded_file.original_filename #=> "nature.jpg"
    #       uploaded_file.mime_type         #=> "image/jpeg"
    #
    #       # ...
    #     end
    #
    # ## Downloading
    #
    # When a derivation is requested, the original uploaded file will be
    # downloaded to disk before the derivation block is called. If you want
    # to pass in additional storage-specific download options, you can do so
    # via `:download_options`:
    #
    #     plugin :derivation_endpoint, download_options: {
    #       sse_customer_algorithm: "AES256",
    #       sse_customer_key:       "secret_key",
    #       sse_customer_key_md5:   "secret_key_md5",
    #     }
    #
    # When using `Shrine.derivation_endpoint` or `Shrine.derivation_response`,
    # if the original uploaded file has been deleted, the error the storage
    # raises when attempting to download it will be propagated by default. You
    # can choose to have the endpoint convert these errors to 404 responses by
    # adding them to `:download_errors`:
    #
    #     plugin :derivation_endpoint, download_errors: [
    #       Errno::ENOENT,              # raised by Shrine::Storage::FileSystem
    #       Aws::S3::Errors::NoSuchKey, # raised by Shrine::Storage::S3
    #     ]
    #
    # If you don't want the uploaded file to be downloaded to disk for you, set
    # `:download` to `false`.
    #
    #     plugin :derivation_endpoint, download: false
    #
    # In this case the `UploadedFile` object is yielded to the derivation block
    # instead of the raw file:
    #
    #     derivation :thumbnail do |uploaded_file, width, height|
    #       uploaded_file #=> #<Shrine::UploadedFile>
    #
    #       # ...
    #     end
    #
    # ## Plugin Options
    #
    # :disposition
    # :  Whether the browser should attempt to render the derivative (`inline`)
    #    or prompt the user to download the file to disk (`attachment`)
    #    (default: `inline`)
    #
    # :download
    # :  Whether the source uploaded file should be downloaded to disk when the
    #    derivation block is called (default: `true`).
    #
    # :download_errors
    # :  List of error classes that will be converted to a `404 Not Found`
    #    response by the derivation endpoint (default: `[]`)
    #
    # :download_options
    # :  Additional options to pass when downloading the source uploaded file
    #    (default: `{}`)
    #
    # :expires_in
    # :  Number of seconds after which the URL will not be available anymore
    #    (default: `nil`)
    #
    # :filename
    # :  Filename the browser will assume when the derivative is downloaded to
    #    disk (default: `<name>-<args>-<source id basename>`)
    #
    # :host
    # :  URL host to use when generated URLs (default: `nil`)
    #
    # :include_uploaded_file
    # :  Whether to include the source uploaded file in the derivation block
    #    arguments (default: `false`)
    #
    # :metadata
    # :  List of metadata keys the source uploaded file should include in the
    #    derivation block (default: `[]`)
    #
    # :prefix
    # :  Path prefix added to the URLs (default: `nil`)
    #
    # :secret_key
    # :  Key that's used to sign derivation URLs in order to prevent tampering
    #    (required)
    #
    # :type
    # :  Media type returned in the `Content-Type` response header in the
    #    derivation response (default: determined from derivative's extension)
    #
    # :upload
    # :  Whether the generated derivatives will be cached on the storage
    #    (default: `false`)
    #
    # :upload_location
    # :  Location to which the derivatives will be uploaded on the storage
    #    (default: `<source id>/<name>-<args>`)
    #
    # :upload_options
    # :  Additional options to be passed when uploading derivatives
    #    (default: `{}`)
    #
    # :upload_redirect
    # :  Whether the derivation response should redirect to the uploaded
    #    derivative (default: `false`)
    #
    # :upload_redirect_url_options
    # :  Additional options to be passed when generating the URL for the
    #    uploaded derivative (default: `{}`)
    #
    # :upload_storage
    # :  Storage to which the derivations will be uploaded (default: same
    #    storage as the source file)
    #
    # :version
    # :  Version number to append to the URL for cache busting (default: `nil`)
    #
    # [ImageProcessing]: https://github.com/janko-m/image_processing
    # [`Content-Type`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type
    # [`Content-Disposition`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition
    module DerivationEndpoint
      class SourceNotFound < Error; end

      def self.load_dependencies(uploader, opts = {})
        uploader.plugin :rack_response if opts[:upload] && opts[:upload_redirect] != true
        uploader.plugin :_urlsafe_serialization
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:derivation_endpoint_options] ||= {}
        uploader.opts[:derivation_endpoint_options].merge!(opts)

        uploader.opts[:derivation_endpoint_definitions] ||= {}

        unless uploader.opts[:derivation_endpoint_options][:secret_key]
          fail Error, ":secret_key option is required for derivation_endpoint plugin"
        end
      end

      module ClassMethods
        def derivation_endpoint(**options)
          App.new(shrine_class: self, options: options)
        end

        def derivation_response(env, **options)
          script_name = env["SCRIPT_NAME"]
          path_info   = env["PATH_INFO"]

          prefix = derivation_options[:prefix]
          match  = path_info.match(/^\/#{prefix}/)

          fail Error, "expected request path \"#{path_info}\" to start with \"/#{prefix}\"" unless match

          begin
            env["SCRIPT_NAME"] += match.to_s
            env["PATH_INFO"]    = match.post_match

            derivation_endpoint(**options).call(env)
          ensure
            env["SCRIPT_NAME"] = script_name
            env["PATH_INFO"]   = path_info
          end
        end

        def derivation(name, &block)
          derivations[name] = block
        end

        def find_derivation(name)
          derivations[name] or fail Error, "derivation #{name.inspect} is not defined"
        end

        def derivations
          opts[:derivation_endpoint_definitions]
        end

        def derivation_options
          opts[:derivation_endpoint_options]
        end
      end

      module FileMethods
        def derivation_url(name, *args, **options)
          derivation(name, *args).url(**options)
        end

        def derivation_response(name, *args, env:, **options)
          derivation(name, *args, **options).response(env)
        end

        private

        def derivation(name, *args, **options)
          Derivation.new(
            name:    name,
            args:    args,
            source:  self,
            options: options,
          )
        end
      end

      class Derivation
        def self.option(name, default: nil)
          define_method(name) do
            value = resolve_option(name)
            value = instance_exec(&default) if value.nil? && default
            value
          end
          private(name)
        end

        attr_reader :name, :args, :source, :options

        def initialize(name:, args:, source:, options:)
          @name    = name
          @args    = args
          @source  = source
          @options = options
        end

        option :disposition,                 default: -> { "inline" }
        option :download,                    default: -> { true }
        option :download_errors,             default: -> { [] }
        option :download_options,            default: -> { {} }
        option :expires_in
        option :filename,                    default: -> { default_filename }
        option :host
        option :include_uploaded_file,       default: -> { false }
        option :metadata,                    default: -> { [] }
        option :prefix
        option :secret_key
        option :type
        option :upload,                      default: -> { false }
        option :upload_location,             default: -> { default_upload_location }
        option :upload_options,              default: -> { {} }
        option :upload_redirect,             default: -> { false }
        option :upload_redirect_url_options, default: -> { {} }
        option :upload_storage,              default: -> { source.storage_key.to_sym }
        option :version

        def url(**options)
          derivation_url = Derivation::Url.new(
            name:       name,
            args:       args,
            file:       source,
            secret_key: secret_key,
          )

          derivation_url.call(
            host:       host,
            prefix:     prefix,
            expires_in: expires_in,
            version:    version,
            metadata:   metadata,
            **options,
          )
        end

        def response(env)
          derivation_response = Derivation::Response.new(
            name:                        name,
            args:                        args,
            source:                      source,
            env:                         env,
            type:                        type,
            disposition:                 disposition,
            filename:                    filename,
            download:                    download,
            download_errors:             download_errors,
            download_options:            download_options,
            include_uploaded_file:       include_uploaded_file,
            upload:                      upload,
            upload_storage:              upload_storage,
            upload_location:             upload_location,
            upload_options:              upload_options,
            upload_redirect:             upload_redirect,
            upload_redirect_url_options: upload_redirect_url_options,
            version:                     version,
          )

          derivation_response.call
        end

        private

        def resolve_option(name)
          value = options.fetch(name) { shrine_class.derivation_options[name] }
          value = value.call(name: name, args: args, uploaded_file: source) if value.respond_to?(:call)
          value
        end

        def default_filename
          [name, *args, File.basename(source.id, ".*")].join("-")
        end

        def default_upload_location
          directory = source.id.sub(/\.[^\/]+/, "")
          filename  = [name, *args].join("-")

          [directory, filename].join("/")
        end

        def shrine_class
          source.shrine_class
        end
      end

      class Derivation::Url
        attr_reader :name, :args, :file, :secret_key

        def initialize(name:, args:, file:, secret_key:)
          @name       = name
          @args       = args
          @file       = file
          @secret_key = secret_key
        end

        def call(host: nil, prefix: nil, **options)
          [host, *prefix, identifier(**options)].join("/")
        end

        private

        def identifier(expires_in: nil,
                       version: nil,
                       type: nil,
                       filename: nil,
                       disposition: nil,
                       metadata: [])

          params = {}
          params[:expires_at]  = (Time.now.utc + expires_in).to_i if expires_in
          params[:version]     = version if version
          params[:type]        = type if type
          params[:filename]    = filename if filename
          params[:disposition] = disposition if disposition

          file_component = file.urlsafe_dump(metadata: metadata)

          signed_url(name, *args, file_component, params)
        end

        def signed_url(*components)
          signer = Signer.new(secret_key)
          signer.signed_url(*components)
        end
      end

      class App
        attr_reader :shrine_class, :options

        def initialize(shrine_class:, options: {})
          @shrine_class = shrine_class
          @options      = options
        end

        def call(env)
          request = Rack::Request.new(env)

          status, headers, body = catch(:halt) do
            error!(405, "Method not allowed") unless request.get? || request.head?

            handle_request(request)
          end

          headers["Content-Length"] ||= body.map(&:bytesize).inject(0, :+).to_s

          [status, headers, body]
        end

        def handle_request(request)
          verify_signature!(request)
          check_expiry!(request)

          name, *args, serialized_file = request.path_info.split("/")[1..-1]

          name          = name.to_sym
          uploaded_file = shrine_class::UploadedFile.urlsafe_load(serialized_file)

          unless shrine_class.derivations.key?(name)
            error!(404, "Unknown derivation \"#{name}\"")
          end

          # request params override statically configured options
          options = self.options.dup
          options[:type]        = request.params["type"]        if request.params["type"]
          options[:disposition] = request.params["disposition"] if request.params["disposition"]
          options[:filename]    = request.params["filename"]    if request.params["filename"]

          begin
            status, headers, body = uploaded_file.derivation_response(
              name, *args, env: request.env, **options,
            )
          rescue SourceNotFound
            error!(404, "Source file not found")
          end

          if status == 200 || status == 206
            if request.params["expires_at"]
              headers["Cache-Control"] = "public, max-age=#{expires_in(request)}" # cache until the URL expires
            else
              headers["Cache-Control"] = "public, max-age=#{365*24*60*60}" # cache for a year
            end
          end

          [status, headers, body]
        end

        private

        def verify_signature!(request)
          signer = Signer.new(secret_key)
          signer.verify_url("#{request.path_info[1..-1]}?#{request.query_string}")
        rescue Signer::InvalidSignature => error
          error!(403, error.message.capitalize)
        end

        def check_expiry!(request)
          if request.params["expires_at"]
            error!(403, "Request has expired") if expires_in(request) <= 0
          end
        end

        def expires_in(request)
          expires_at = Integer(request.params["expires_at"])

          (Time.at(expires_at) - Time.now).to_i
        end

        # Halts the request with the error message.
        def error!(status, message)
          throw :halt, [status, { "Content-Type" => "text/plain" }, [message]]
        end

        def secret_key
          shrine_class.derivation_options[:secret_key]
        end
      end

      class Derivation::Response
        DEFAULT_MIME_TYPE = "application/octet-stream"

        attr_reader :name, :args, :source, :env, :type, :disposition,
          :filename, :download, :download_errors, :download_options, :upload,
          :upload_storage, :upload_options, :upload_redirect,
          :upload_redirect_url_options, :include_uploaded_file, :version

        def initialize(**options)
          options.each do |name, value|
            instance_variable_set(:"@#{name}", value)
          end
        end

        def call
          if upload
            upload_response
          else
            local_response
          end
        end

        private

        def local_response
          derivative = call_derivation

          file_response(derivative)
        end

        def file_response(file)
          file.close
          response = rack_file_response(file.path)

          status = response[0]

          filename  = self.filename
          filename += File.extname(file.path) if File.extname(filename).empty?

          headers = {}
          headers["Content-Type"]        = type || response[1]["Content-Type"]
          headers["Content-Disposition"] = content_disposition(filename)
          headers["Content-Length"]      = response[1]["Content-Length"]
          headers["Content-Range"]       = response[1]["Content-Range"] if response[1]["Content-Range"]
          headers["Accept-Ranges"]       = "bytes"

          body = Rack::BodyProxy.new(response[2]) { file.delete }

          [status, headers, body]
        end

        def upload_response
          storage = shrine_class.find_storage(upload_storage)

          if storage.exists?(upload_location)
            uploaded_file = shrine_class::UploadedFile.new(
              "storage" => upload_storage,
              "id"      => upload_location,
            )
          else
            derivative = call_derivation

            uploader      = shrine_class.new(upload_storage)
            uploaded_file = uploader.upload derivative,
              location:       upload_location,
              upload_options: upload_options
          end

          if upload_redirect
            derivative.unlink if derivative

            redirect_url = uploaded_file.url(upload_redirect_url_options)

            [302, { "Location" => redirect_url }, []]
          else
            if derivative
              file_response(derivative)
            else
              uploaded_file.to_rack_response(
                type:        type,
                disposition: disposition,
                filename:    filename,
                range:       env["HTTP_RANGE"],
              )
            end
          end
        end

        def call_derivation
          derivation_block = shrine_class.find_derivation(name)
          uploader         = source.uploader

          derivative = if download
            download_source do |file|
              if include_uploaded_file
                uploader.instance_exec(file, source, *args, &derivation_block)
              else
                uploader.instance_exec(file, *args, &derivation_block)
              end
            end
          else
            uploader.instance_exec(source, *args, &derivation_block)
          end

          unless derivative.respond_to?(:path)
            fail Error, "expected derivative to be a file object, but was #{derivative.inspect}"
          end

          derivative
        end

        def download_source
          download_args = [download_options].reject(&:empty?)

          begin
            file = source.download(*download_args)
          rescue *download_errors
            raise SourceNotFound, "source uploaded file \"#{source.id}\" was not found on storage :#{source.storage_key}"
          end

          yield file
        ensure
          file.close! if file
        end

        def rack_file_response(path)
          server = Rack::File.new("", {}, DEFAULT_MIME_TYPE)

          if Rack.release > "2"
            server.serving(Rack::Request.new(env), path)
          else
            server = server.dup
            server.path = path
            server.serving(env)
          end
        end

        def content_disposition(filename)
          ContentDisposition.format(disposition: disposition, filename: filename)
        end

        def upload_location
          if version
            @upload_location.sub(/(?=(\.\w+)?$)/, "-#{version}")
          else
            @upload_location
          end
        end

        def shrine_class
          source.shrine_class
        end
      end

      class Signer
        InvalidSignature = Class.new(StandardError)

        attr_reader :secret_key

        def initialize(secret_key)
          @secret_key = secret_key
        end

        def signed_url(*components, params)
          path  = Rack::Utils.escape_path(components.join("/"))
          query = Rack::Utils.build_query(params)

          signature = generate_signature("#{path}?#{query}")

          query = Rack::Utils.build_query(params.merge(signature: signature))

          "#{path}?#{query}"
        end

        def verify_url(path_with_query)
          path, query = path_with_query.split("?")

          params    = Rack::Utils.parse_query(query.to_s)
          signature = params.delete("signature")
          query     = Rack::Utils.build_query(params)

          verify_signature("#{path}?#{query}", signature)
        end

        def verify_signature(string, signature)
          if signature.nil?
            fail InvalidSignature, "signature is missing"
          elsif signature != generate_signature(string)
            fail InvalidSignature, "provided signature doesn't match the expected"
          end
        end

        def generate_signature(string)
          OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, secret_key, string)
        end
      end
    end

    register_plugin(:derivation_endpoint, DerivationEndpoint)
  end
end
