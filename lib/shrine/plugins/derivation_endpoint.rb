# frozen_string_literal: true

require "rack"
require "content_disposition"

require "openssl"
require "tempfile"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/derivation_endpoint.md] on GitHub.
    #
    # [doc/plugins/derivation_endpoint.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/derivation_endpoint.md
    module DerivationEndpoint
      def self.load_dependencies(uploader, opts = {})
        uploader.plugin :rack_response
        uploader.plugin :_urlsafe_serialization
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:derivation_endpoint_options] ||= {}
        uploader.opts[:derivation_endpoint_options].merge!(opts)

        uploader.opts[:derivation_endpoint_derivations] ||= {}

        unless uploader.opts[:derivation_endpoint_options][:secret_key]
          fail Error, "must provide :secret_key option to derivation_endpoint plugin"
        end
      end

      module ClassMethods
        # Returns a mountable Rack app that handles derivation requests.
        def derivation_endpoint(**options)
          Shrine::DerivationEndpoint.new(shrine_class: self, options: options)
        end

        # Calls the derivation endpoint passing the request information, and
        # returns the Rack response triple.
        #
        # It uses a trick where it removes the derivation path prefix from the
        # path info before calling the Rack app, which is what web framework
        # routers do before they're calling a mounted Rack app.
        def derivation_response(env, **options)
          script_name = env["SCRIPT_NAME"]
          path_info   = env["PATH_INFO"]

          prefix = derivation_options[:prefix]
          match  = path_info.match(/^\/#{prefix}/)

          fail Error, "request path must start with \"/#{prefix}\", but is \"#{path_info}\"" unless match

          begin
            env["SCRIPT_NAME"] += match.to_s
            env["PATH_INFO"]    = match.post_match

            derivation_endpoint(**options).call(env)
          ensure
            env["SCRIPT_NAME"] = script_name
            env["PATH_INFO"]   = path_info
          end
        end

        # Registers a derivation block, which is called when the corresponding
        # derivation URL is requested.
        def derivation(name, &block)
          derivations[name] = block
        end

        def derivations
          opts[:derivation_endpoint_derivations]
        end

        def derivation_options
          opts[:derivation_endpoint_options]
        end
      end

      module FileMethods
        # Generates a URL to a derivation with the receiver as the source file.
        # Any arguments provided will be included in the URL and passed to the
        # derivation block. Accepts additional URL options.
        def derivation_url(name, *args, **options)
          derivation(name, *args).url(**options)
        end

        # Calls the specified derivation with the receiver as the source file,
        # returning a Rack response triple. The derivation endpoint ultimately
        # calls this method.
        def derivation_response(name, *args, env:, **options)
          derivation(name, *args, **options).response(env)
        end

        # Returns a Shrine::Derivation object created from the provided
        # arguments. This object offers additional methods for operating with
        # derivatives on a lower level.
        def derivation(name, *args, **options)
          Shrine::Derivation.new(
            name:    name,
            args:    args,
            source:  self,
            options: options,
          )
        end
      end
    end

    register_plugin(:derivation_endpoint, DerivationEndpoint)
  end

  class Derivation
    class NotFound       < Error; end
    class SourceNotFound < Error; end

    attr_reader :name, :args, :source, :options

    def initialize(name:, args:, source:, options:)
      @name    = name
      @args    = args
      @source  = source
      @options = options
    end

    # Returns an URL to the derivation.
    def url(**options)
      Derivation::Url.new(self).call(
        host:       option(:host),
        prefix:     option(:prefix),
        expires_in: option(:expires_in),
        version:    option(:version),
        metadata:   option(:metadata),
        **options,
      )
    end

    # Returns the derivation result in form of a Rack response triple.
    def response(env)
      Derivation::Response.new(self).call(env)
    end

    # Returns the derivation result as a File/Tempfile or a
    # Shrine::UploadedFile object.
    def processed
      Derivation::Processed.new(self).call
    end

    # Calls the derivation block and returns the direct result.
    def generate(file = nil)
      Derivation::Generate.new(self).call(file)
    end

    # Uploads the derivation result to a dedicated destination on the specified
    # Shrine storage.
    def upload(file = nil)
      Derivation::Upload.new(self).call(file)
    end

    # Returns a Shrine::UploadedFile object pointing to the uploaded derivation
    # result.
    def retrieve
      Derivation::Retrieve.new(self).call
    end

    # Deletes the derivation result from the storage.
    def delete
      Derivation::Delete.new(self).call
    end

    def self.options
      @options ||= {}
    end

    def self.option(name, default: nil, result: nil)
      options[name] = { default: default, result: result }
    end

    option :cache_control,               default: -> { default_cache_control }
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
    option :upload_location,             default: -> { default_upload_location }, result: -> (o) { upload_location(o) }
    option :upload_open_options,         default: -> { {} }
    option :upload_options,              default: -> { {} }
    option :upload_redirect,             default: -> { false }
    option :upload_redirect_url_options, default: -> { {} }
    option :upload_storage,              default: -> { source.storage_key.to_sym }
    option :version

    # Retrieves the value of a derivation option.
    #
    # * If specified as a raw value, returns that value
    # * If specified as a block, evaluates that it and returns the result
    # * If unspecified, returns the default value
    def option(name)
      option_definition = self.class.options.fetch(name)

      value = options.fetch(name) { shrine_class.derivation_options[name] }
      value = instance_exec(&value) if value.is_a?(Proc)

      if value.nil?
        default = option_definition[:default]
        value   = instance_exec(&default) if default
      end

      result = option_definition[:result]
      value  = instance_exec(value, &result) if result

      value
    end

    def shrine_class
      source.shrine_class
    end

    private

    # When bumping the version, we also append it to the upload location to
    # ensure we're not retrieving old derivatives.
    def upload_location(location)
      location = location.sub(/(?=(\.\w+)?$)/, "-#{option(:version)}") if option(:version)
      location
    end

    # For derivation "thumbnail" with arguments "600/400" and source id of
    # "1f6375ad.ext", returns "thumbnail-600-400-1f6375ad".
    def default_filename
      [name, *args, File.basename(source.id, ".*")].join("-")
    end

    # For derivation "thumbnail" with arguments "600/400" and source id of
    # "1f6375ad.ext", returns "1f6375ad/thumbnail-600-400".
    def default_upload_location
      directory = source.id.sub(/\.[^\/]+/, "")
      filename  = [name, *args].join("-")

      [directory, filename].join("/")
    end

    # Allows caching for 1 year or until the URL expires.
    def default_cache_control
      if option(:expires_in)
        "public, max-age=#{option(:expires_in)}"
      else
        "public, max-age=#{365*24*60*60}"
      end
    end

    class Command
      attr_reader :derivation

      def initialize(derivation)
        @derivation = derivation
      end

      # Creates methods that delegate to derivation parameters.
      def self.delegate(*names)
        names.each do |name|
          protected define_method(name) {
            if [:name, :args, :source].include?(name)
              derivation.public_send(name)
            else
              derivation.option(name)
            end
          }
        end
      end

      private

      def shrine_class
        derivation.shrine_class
      end
    end
  end

  class Derivation::Url < Derivation::Command
    delegate :name, :args, :source, :secret_key

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
      params[:expires_at]  = (Time.now + expires_in).to_i if expires_in
      params[:version]     = version if version
      params[:type]        = type if type
      params[:filename]    = filename if filename
      params[:disposition] = disposition if disposition

      # serializes the source uploaded file into an URL-safe format
      source_component = source.urlsafe_dump(metadata: metadata)

      # generate signed URL
      signed_url(name, *args, source_component, params)
    end

    def signed_url(*components)
      signer = UrlSigner.new(secret_key)
      signer.signed_url(*components)
    end
  end

  class DerivationEndpoint
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

    # Verifies validity of the URL, then extracts parameters from it (such as
    # derivation name, arguments and source file), and generates a derivation
    # response.
    #
    # Returns "403 Forbidden" if signature is invalid, or if the URL has
    # expired.
    #
    # Returns "404 Not Found" if derivation block is not defined, or if source
    # file was not found on the storage.
    def handle_request(request)
      verify_signature!(request)
      check_expiry!(request)

      name, *args, serialized_file = request.path_info.split("/")[1..-1]

      name          = name.to_sym
      uploaded_file = shrine_class::UploadedFile.urlsafe_load(serialized_file)

      # request params override statically configured options
      options = self.options.dup
      options[:type]        = request.params["type"]        if request.params["type"]
      options[:disposition] = request.params["disposition"] if request.params["disposition"]
      options[:filename]    = request.params["filename"]    if request.params["filename"]
      options[:expires_in]  = expires_in(request)           if request.params["expires_at"]

      derivation = uploaded_file.derivation(name, *args, **options)

      begin
        status, headers, body = derivation.response(request.env)
      rescue Derivation::NotFound
        error!(404, "Unknown derivation \"#{name}\"")
      rescue Derivation::SourceNotFound
        error!(404, "Source file not found")
      end

      # tell clients to cache the derivation result if it was successful
      if status == 200 || status == 206
        headers["Cache-Control"] = derivation.option(:cache_control)
      end

      [status, headers, body]
    end

    private

    # Return an error response if the signature is invalid.
    def verify_signature!(request)
      signer = UrlSigner.new(secret_key)
      signer.verify_url("#{request.path_info[1..-1]}?#{request.query_string}")
    rescue UrlSigner::InvalidSignature => error
      error!(403, error.message.capitalize)
    end

    # Return an error response if URL has expired.
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
      derivation_options[:secret_key]
    end

    def derivation_options
      shrine_class.derivation_options.merge(self.options)
    end
  end

  class Derivation::Response < Derivation::Command
    delegate :type, :disposition, :filename,
             :upload, :upload_open_options,
             :upload_redirect, :upload_redirect_url_options

    def call(env)
      if upload
        upload_response(env)
      else
        local_response(env)
      end
    end

    private

    def local_response(env)
      derivative = derivation.generate

      file_response(derivative, env)
    end

    # Generates a Rack response triple from a local file using `Rack::File`.
    # Fills in `Content-Type` and `Content-Disposition` response headers from
    # derivation options and file extension of the derivation result.
    def file_response(file, env)
      response = rack_file_response(file.path, env)

      status = response[0]

      content_type   = type || response[1]["Content-Type"]
      content_length = response[1]["Content-Length"]
      content_range  = response[1]["Content-Range"]

      filename  = self.filename
      filename += File.extname(file.path) if File.extname(filename).empty?

      headers = {}
      headers["Content-Type"]        = content_type if content_type
      headers["Content-Disposition"] = content_disposition(filename)
      headers["Content-Length"]      = content_length
      headers["Content-Range"]       = content_range if content_range
      headers["Accept-Ranges"]       = "bytes"

      body = Rack::BodyProxy.new(response[2]) { File.delete(file.path) }

      file.close

      [status, headers, body]
    end

    # This is called when `:upload` is enabled. Checks the storage for already
    # uploaded derivation result, otherwise calls the derivation block and
    # uploads the result. If the derivation result is already uploaded, uses
    # the `rack_response` plugin to generate a Rack response triple.
    def upload_response(env)
      uploaded_file = derivation.retrieve

      unless uploaded_file
        derivative    = derivation.generate
        uploaded_file = derivation.upload(derivative)
      end

      if upload_redirect
        # we don't need the local derivation result here
        if derivative
          derivative.close
          File.delete(derivative.path)
        end

        redirect_url = uploaded_file.url(upload_redirect_url_options)

        [302, { "Location" => redirect_url }, []]
      else
        if derivative
          file_response(derivative, env)
        else
          uploaded_file.open(**upload_open_options)
          uploaded_file.to_rack_response(
            type:        type,
            disposition: disposition,
            filename:    filename,
            range:       env["HTTP_RANGE"],
          )
        end
      end
    end

    # We call `Rack::File` with no default `Content-Type`, and make sure we
    # stay compatible with both Rack 2.x and 1.6.x.
    def rack_file_response(path, env)
      server = Rack::File.new("", {}, nil)

      if Rack.release > "2"
        server.serving(Rack::Request.new(env), path)
      else
        server = server.dup
        server.path = path
        server.serving(env)
      end
    end

    # Returns disposition and filename formatted for the `Content-Disposition`
    # header.
    def content_disposition(filename)
      ContentDisposition.format(disposition: disposition, filename: filename)
    end
  end

  class Derivation::Processed < Derivation::Command
    delegate :upload

    def call
      if upload
        derivation.retrieve || derivation.upload
      else
        derivation.generate
      end
    end
  end

  class Derivation::Generate < Derivation::Command
    delegate :name, :args, :source,
             :download, :download_errors, :download_options,
             :include_uploaded_file

    def call(file = nil)
      derivative = generate(file)
      derivative = normalize(derivative)
      derivative
    end

    private

    # Calls the derivation block with the source file and derivation arguments.
    # If a file object is given, passes that as the source file, otherwise
    # downloads the source uploaded file.
    def generate(file)
      if download
        with_downloaded(file) do |file|
          if include_uploaded_file
            uploader.instance_exec(file, source, *args, &derivation_block)
          else
            uploader.instance_exec(file, *args, &derivation_block)
          end
        end
      else
        uploader.instance_exec(source, *args, &derivation_block)
      end
    end

    # Massages the derivation result, ensuring it's opened in binary mode,
    # rewinded and flushed to disk.
    def normalize(derivative)
      if derivative.is_a?(Tempfile)
        derivative.open
      elsif derivative.is_a?(File)
        derivative.close
        derivative = File.open(derivative.path)
      elsif derivative.is_a?(String)
        derivative = File.open(derivative)
      elsif defined?(Pathname) && derivative.is_a?(Pathname)
        derivative = derivative.open
      else
        fail Error, "unexpected derivation result: #{derivation.inspect} (expected File, Tempfile, String, or Pathname object)"
      end

      derivative.binmode
      derivative
    end

    def with_downloaded(file, &block)
      if file
        yield file
      else
        download_source(&block)
      end
    end

    # Downloads the source uploaded file from the storage.
    def download_source
      begin
        file = source.download(**download_options)
      rescue *download_errors
        raise Derivation::SourceNotFound, "source file \"#{source.id}\" was not found on storage :#{source.storage_key}"
      end

      yield file
    ensure
      file.close! if file
    end

    def derivation_block
      shrine_class.derivations[name] or fail Derivation::NotFound, "derivation #{name.inspect} is not defined"
    end

    def uploader
      source.uploader
    end
  end

  class Derivation::Upload < Derivation::Command
    delegate :upload_location, :upload_storage, :upload_options

    # Uploads the derivation result to the dedicated location on the storage.
    # If a file object is given, uploads that to the storage, otherwise calls
    # the derivation block and uploads the result.
    def call(derivative = nil)
      with_derivative(derivative) do |uploadable|
        uploader.upload uploadable,
          location:       upload_location,
          upload_options: upload_options,
          delete:         false, # disable delete_raw plugin
          move:           false # disable moving plugin
      end
    end

    private

    def with_derivative(derivative)
      if derivative
        # we want to keep the provided file open and rewinded
        File.open(derivative.path, binmode: true) do |file|
          yield file
        end
      else
        # generate the derivative and delete it afterwards
        begin
          file = derivation.generate
          yield file
        ensure
          file.close
          File.delete(file.path)
        end
      end
    end

    def uploader
      shrine_class.new(upload_storage)
    end
  end

  class Derivation::Retrieve < Derivation::Command
    delegate :upload_location, :upload_storage

    # Returns a Shrine::UploadedFile object pointing to the uploaded derivation
    # result it exists on the storage.
    def call
      if storage.exists?(upload_location)
        shrine_class::UploadedFile.new(
          "storage" => upload_storage.to_s,
          "id"      => upload_location,
        )
      end
    end

    private

    def storage
      shrine_class.find_storage(upload_storage)
    end
  end

  class Derivation::Delete < Derivation::Command
    delegate :upload_location, :upload_storage

    # Deletes the uploaded derivation result from the storage.
    def call
      storage.delete(upload_location)
    end

    private

    def storage
      shrine_class.find_storage(upload_storage)
    end
  end

  class UrlSigner
    class InvalidSignature < Error; end

    attr_reader :secret_key

    def initialize(secret_key)
      @secret_key = secret_key
    end

    # Returns a URL with the `signature` query parameter generated from the
    # given path components and query parameters.
    def signed_url(*components, params)
      # When using Rack < 2, Rack::Utils#escape_path will escape '/'.
      # Escape each component and then join them together.
      path = components.map{|component| Rack::Utils.escape_path(component.to_s)}.join('/')
      query = Rack::Utils.build_query(params)

      signature = generate_signature("#{path}?#{query}")

      query = Rack::Utils.build_query(params.merge(signature: signature))

      "#{path}?#{query}"
    end

    # Calculcates the signature from the URL and checks whether it matches the
    # value in the `signature` query parameter. Raises `InvalidSignature` if
    # the `signature` parameter is missing or its value doesn't match the
    # calculated signature.
    def verify_url(path_with_query)
      path, query = path_with_query.split("?")

      params    = Rack::Utils.parse_query(query.to_s)
      signature = params.delete("signature")
      query     = Rack::Utils.build_query(params)

      verify_signature("#{path}?#{query}", signature)
    end

    def verify_signature(string, signature)
      if signature.nil?
        fail InvalidSignature, "missing \"signature\" param"
      elsif signature != generate_signature(string)
        fail InvalidSignature, "provided signature does not match the calculated signature"
      end
    end

    # Uses HMAC-SHA-256 algorithm to generate a signature from the given string
    # using the secret key.
    def generate_signature(string)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, secret_key, string)
    end
  end
end
