# frozen_string_literal: true

require "rack"
require "content_disposition"

require "openssl"
require "tempfile"
require "pathname"

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/derivation_endpoint
    module DerivationEndpoint
      LOG_SUBSCRIBER = -> (event) do
        Shrine.logger.info "Derivation (#{event.duration}ms) – #{{
          name:     event[:derivation].name,
          args:     event[:derivation].args,
          uploader: event[:uploader],
        }.inspect}"
      end

      def self.load_dependencies(uploader, **)
        uploader.plugin :rack_response
        uploader.plugin :_urlsafe_serialization
      end

      def self.configure(uploader, log_subscriber: LOG_SUBSCRIBER, **opts)
        uploader.opts[:derivation_endpoint] ||= { options: {}, derivations: {} }
        uploader.opts[:derivation_endpoint][:options].merge!(opts)

        if !uploader.opts[:derivation_endpoint][:options][:secret_key] && !uploader.opts[:derivation_endpoint][:options][:signer]
          fail Error, "must provide :secret_key option to derivation_endpoint plugin when no custom signer is set"
        end

        # instrumentation plugin integration
        uploader.subscribe(:derivation, &log_subscriber) if uploader.respond_to?(:subscribe)
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
          derivations[name.to_sym] = block
        end

        def derivations
          opts[:derivation_endpoint][:derivations]
        end

        def derivation_options
          opts[:derivation_endpoint][:options]
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
      @name    = name.to_sym
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
    def upload(file = nil, **options)
      Derivation::Upload.new(self).call(file, **options)
    end

    # Returns a Shrine::UploadedFile object pointing to the uploaded derivative
    # if it exists.
    def retrieve
      Derivation::Retrieve.new(self).call
    end

    # Returns opened Shrine::UploadedFile object pointing to the uploaded
    # derivative if it exists.
    def opened
      Derivation::Opened.new(self).call
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
    option :download_options,            default: -> { {} }
    option :expires_in
    option :filename,                    default: -> { default_filename }
    option :host
    option :metadata,                    default: -> { [] }
    option :prefix
    option :secret_key
    option :signer
    option :type
    option :upload,                      default: -> { false }
    option :upload_location,             default: -> { default_upload_location }, result: -> (o) { upload_location(o) }
    option :upload_open_options,         default: -> { {} }
    option :upload_options,              default: -> { {} }
    option :upload_redirect,             default: -> { false }
    option :upload_redirect_url_options, default: -> { {} }
    option :upload_storage,              default: -> { default_upload_storage }
    option :version

    # Retrieves the value of a derivation option.
    #
    # * If specified as a raw value, returns that value
    # * If specified as a block, evaluates that it and returns the result
    # * If unspecified, returns the default value
    def option(name)
      option_definition = self.class.options.fetch(name)

      value = options.fetch(name) { shrine_class.derivation_options[name] }
      value = instance_exec(&value) if value.is_a?(Proc) && value.arity == 0

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

    # The source uploaded file storage is the default derivative storage.
    def default_upload_storage
      source.storage_key
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
    delegate :name, :args, :source, :secret_key, :signer

    def call(host: nil, prefix: nil, **options)
      base_url = [host, *prefix].join("/")
      path = path_identifier(metadata: options.delete(:metadata))

      if signer
        url = [base_url, path].join("/")
        signer.call(url, **options)
      else
        signed_part = signed_url("#{path}?#{query(**options)}")
        [base_url, signed_part].join("/")
      end
    end

    private

    def path_identifier(metadata: [])
      [
        name,
        *args,
        source.urlsafe_dump(metadata: metadata)
      ].map{|component| Rack::Utils.escape_path(component.to_s)}.join('/')
    end

    def query(expires_in: nil,
              type: nil,
              filename: nil,
              disposition: nil,
              version: nil)

      params = {}
      params[:expires_at]  = (Time.now + expires_in).to_i if expires_in
      params[:version]     = version if version
      params[:type]        = type if type
      params[:filename]    = filename if filename
      params[:disposition] = disposition if disposition

      Rack::Utils.build_query(params)
    end

    def signed_url(url)
      signer = UrlSigner.new(secret_key)
      signer.sign_url(url)
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

      headers ||= {}

      if Rack.release >= "3"
        headers["content-length"] ||= body.respond_to?(:bytesize) ? body.bytesize.to_s :
                                                                    body.map(&:bytesize).inject(0, :+).to_s
      else
        headers["Content-Length"] ||= body.map(&:bytesize).inject(0, :+).to_s
      end

      headers = headers.transform_keys(&:downcase) if Rack.release >= "3"

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
      verify_signature!(request) if secret_key
      check_expiry!(request)

      name, *args, serialized_file = request.path_info.split("/")[1..-1]

      name          = name.to_sym
      uploaded_file = shrine_class::UploadedFile.urlsafe_load(serialized_file)

      # request params override statically configured options
      options = self.options.dup
      options[:type]        = request.params["type"]        if request.params["type"]
      options[:disposition] = request.params["disposition"] if request.params["disposition"]
      options[:filename]    = request.params["filename"]    if request.params["filename"]
      options[:version]     = request.params["version"]     if request.params["version"]
      options[:expires_in]  = expires_in(request)           if request.params["expires_at"]

      derivation = uploaded_file.derivation(name, *args, **options)

      begin
        status, headers, body = derivation.response(request.env)
      rescue Derivation::SourceNotFound
        error!(404, "Source file not found")
      rescue Derivation::NotFound
        error!(404, "Unknown derivation \"#{name}\"")
      end

      # tell clients to cache the derivation result if it was successful
      if status == 200 || status == 206
        headers["Cache-Control"] = derivation.option(:cache_control)
      end

      headers = headers.transform_keys(&:downcase) if Rack.release >= "3"

      [status, headers, body]
    end

    def inspect
      "#<#{@shrine_class}::DerivationEndpoint>"
    end
    alias to_s inspect

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
      headers = { "Content-Type" => "text/plain" }

      headers = headers.transform_keys(&:downcase) if Rack.release >= "3"

      throw :halt, [status, headers, [message]]
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

    # Generates a Rack response triple from a local file. Fills in
    # `Content-Type` and `Content-Disposition` response headers from derivation
    # options and file extension of the derivation result.
    def file_response(file, env)
      response = rack_file_response(file.path, env)

      status = response[0]

      headers = if Rack.release >= "3"
        {
          "content-type"        => type || response[1]["content-type"],
          "content-length"      => response[1]["content-length"],
          "content-disposition" => content_disposition(file),
          "content-range"       => response[1]["content-range"],
          "accept-ranges"       => "bytes",
        }.compact
      else
        {
          "Content-Type"        => type || response[1]["Content-Type"],
          "Content-Length"      => response[1]["Content-Length"],
          "Content-Disposition" => content_disposition(file),
          "Content-Range"       => response[1]["Content-Range"],
          "Accept-Ranges"       => "bytes",
        }.compact
      end

      body = Rack::BodyProxy.new(response[2]) { File.delete(file.path) }

      file.close

      headers = headers.transform_keys(&:downcase) if Rack.release >= "3"

      [status, headers, body]
    end

    # This is called when `:upload` is enabled. Checks the storage for already
    # uploaded derivation result, otherwise calls the derivation block and
    # uploads the result. If the derivation result is already uploaded, uses
    # the `rack_response` plugin to generate a Rack response triple.
    def upload_response(env)
      uploaded_file = upload_redirect ? derivation.retrieve : derivation.opened

      unless uploaded_file
        derivative    = derivation.generate
        uploaded_file = derivation.upload(derivative, delete: upload_redirect)
      end

      if upload_redirect
        redirect_url = uploaded_file.url(**upload_redirect_url_options)

        [302, { "Location" => redirect_url }, []]
      else
        if derivative && File.exist?(derivative.path)
          file_response(derivative, env)
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

    # We call `Rack::Files` with no default `Content-Type`, and make sure we
    # stay compatible with both Rack 2.x and 1.6.x.
    def rack_file_response(path, env)
      if Rack.release >= "2.1"
        server = Rack::Files.new("", {}, nil)
      else
        server = Rack::File.new("", {}, nil)
      end

      if Rack.release > "2"
        server.serving(Rack::Request.new(env), path)
      else
        # :nocov:
        server.path = path
        server.serving(env)
        # :nocov:
      end
    end

    # Returns disposition and filename formatted for the `Content-Disposition`
    # header.
    def content_disposition(file)
      filename  = self.filename
      filename += File.extname(file.path) if File.extname(filename).empty?

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
    delegate :name, :args, :source, :download, :download_options

    def call(file = nil)
      derivative = generate(file)
      derivative = normalize(derivative)
      derivative
    end

    private

    # Determines how to call the derivation block. If a file object is given,
    # passes that as the source file, otherwise downloads the source uploaded
    # file.
    def generate(file)
      if download
        with_downloaded(file) { |file| derive(file, *args) }
      else
        derive(*args)
      end
    end

    # Calls the derivation block.
    def derive(*args)
      instrument_derivation do
        derivation.instance_exec(*args, &derivation_block)
      end
    end

    # Sends a `derivation.shrine` event for instrumentation plugin.
    def instrument_derivation(&block)
      return yield unless shrine_class.respond_to?(:instrument)

      shrine_class.instrument(:derivation, { derivation: derivation }, &block)
    end

    # Massages the derivation result, ensuring it's opened in binary mode,
    # rewinded and flushed to disk.
    def normalize(file)
      unless file.is_a?(File) || file.is_a?(Tempfile)
        fail Error, "expected File or Tempfile object as derivation result, got #{file.inspect}"
      end

      file.open if file.is_a?(Tempfile) # refresh file descriptor
      file.binmode                      # ensure binary mode
      file
    end

    def with_downloaded(file, &block)
      return yield(file) if file

      download_source(&block)
    end

    # Downloads the source uploaded file from the storage.
    def download_source(&block)
      source.download(**download_options, &block)
    rescue Shrine::FileNotFound
      raise Derivation::SourceNotFound, "source file \"#{source.id}\" was not found on storage :#{source.storage_key}"
    end

    def derivation_block
      shrine_class.derivations[name] or fail Derivation::NotFound, "derivation #{name.inspect} is not defined"
    end
  end

  class Derivation::Upload < Derivation::Command
    delegate :upload_location, :upload_storage, :upload_options

    # Uploads the derivation result to the dedicated location on the storage.
    # If a file object is given, uploads that to the storage, otherwise calls
    # the derivation block and uploads the result.
    def call(derivative = nil, **options)
      if derivative
        upload(derivative, **options)
      else
        upload(derivation.generate, delete: true, **options)
      end
    end

    private

    def upload(io, **options)
      shrine_class.upload io, upload_storage,
        location:       upload_location,
        upload_options: upload_options,
        action:         :derivation,
        **options
    end
  end

  class Derivation::Retrieve < Derivation::Command
    delegate :upload_storage, :upload_location

    # Returns a Shrine::UploadedFile object pointing to the uploaded derivative
    # if it exists on the storage.
    def call
      uploaded_file = shrine_class.uploaded_file(storage: upload_storage, id: upload_location)
      uploaded_file if uploaded_file.exists?
    end
  end

  class Derivation::Opened < Derivation::Command
    delegate :upload_storage, :upload_location, :upload_open_options

    # Returns opened Shrine::UploadedFile object pointing to the uploaded if
    # it exists on the storage.
    def call
      uploaded_file = shrine_class.uploaded_file(storage: upload_storage, id: upload_location)
      uploaded_file.open(**upload_open_options)
      uploaded_file
    rescue Shrine::FileNotFound
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

    # Returns a URL with the `signature` query parameter
    def sign_url(url)
      path, query = url.split("?")

      params = Rack::Utils.parse_query(query.to_s)
      params.merge!("signature" => generate_signature(url))

      query = Rack::Utils.build_query(params)

      "#{path}?#{query}"
    end

    # Calculcates the signature from the URL and checks whether it matches the
    # value in the `signature` query parameter. Raises `InvalidSignature` if
    # the `signature` parameter is missing or its value doesn't match the
    # calculated signature.
    def verify_url(url)
      path, query = url.split("?")

      params    = Rack::Utils.parse_query(query.to_s)
      signature = params.delete("signature")

      query = Rack::Utils.build_query(params)

      verify_signature("#{path}?#{query}", signature)
    end

    def verify_signature(string, signature)
      if signature.nil?
        fail InvalidSignature, "missing \"signature\" param"
      elsif !Rack::Utils.secure_compare(signature, generate_signature(string))
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
