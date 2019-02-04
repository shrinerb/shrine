# frozen_string_literal: true

require "rack"
require "content_disposition"

require "openssl"
require "tempfile"

class Shrine
  module Plugins
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
        def derivation_endpoint(**options)
          Shrine::DerivationEndpoint.new(shrine_class: self, options: options)
        end

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
        def derivation_url(name, *args, **options)
          derivation(name, *args).url(**options)
        end

        def derivation_response(name, *args, env:, **options)
          derivation(name, *args, **options).response(env)
        end

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

    def response(env)
      Derivation::Response.new(self).call(env)
    end

    def processed
      Derivation::Processed.new(self).call
    end

    def generate(file = nil)
      Derivation::Generate.new(self).call(file)
    end

    def upload(file = nil)
      Derivation::Upload.new(self).call(file)
    end

    def retrieve
      Derivation::Retrieve.new(self).call
    end

    def delete
      Derivation::Delete.new(self).call
    end

    def self.options
      @options ||= {}
    end

    def self.option(name, default: nil, result: nil)
      options[name] = { default: default, result: result }
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
    option :upload_location,             default: -> { default_upload_location }, result: -> (l) { upload_location(l) }
    option :upload_options,              default: -> { {} }
    option :upload_redirect,             default: -> { false }
    option :upload_redirect_url_options, default: -> { {} }
    option :upload_storage,              default: -> { source.storage_key.to_sym }
    option :version

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

    # append version and extension to upload location if specified
    def upload_location(location)
      location = location.sub(/(?=(\.\w+)?$)/, "-#{option(:version)}") if option(:version)
      location
    end

    def default_filename
      [name, *args, File.basename(source.id, ".*")].join("-")
    end

    def default_upload_location
      directory = source.id.sub(/\.[^\/]+/, "")
      filename  = [name, *args].join("-")

      [directory, filename].join("/")
    end

    class Command
      attr_reader :derivation

      def initialize(derivation)
        @derivation = derivation
      end

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
      params[:expires_at]  = (Time.now.utc + expires_in).to_i if expires_in
      params[:version]     = version if version
      params[:type]        = type if type
      params[:filename]    = filename if filename
      params[:disposition] = disposition if disposition

      source_component = source.urlsafe_dump(metadata: metadata)

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

      begin
        status, headers, body = uploaded_file.derivation_response(
          name, *args, env: request.env, **options,
        )
      rescue Derivation::NotFound
        error!(404, "Unknown derivation \"#{name}\"")
      rescue Derivation::SourceNotFound
        error!(404, "Source file not found")
      end

      if status == 200 || status == 206
        headers["Cache-Control"] = cache_control(request)
      end

      [status, headers, body]
    end

    private

    def verify_signature!(request)
      signer = UrlSigner.new(secret_key)
      signer.verify_url("#{request.path_info[1..-1]}?#{request.query_string}")
    rescue UrlSigner::InvalidSignature => error
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
      derivation_options[:secret_key]
    end

    def cache_control(request)
      directives = { public: true, max_age: 365*24*60*60 }
      directives[:max_age] = expires_in(request) if request.params["expires_at"]
      directives.merge!(derivation_options[:cache_control]) if derivation_options[:cache_control]

      directives
        .reject { |key, value| value == nil || value == false }
        .map    { |key, value| [key.to_s.tr("_", "-"), value] }
        .map    { |key, value| value == true ? key : "#{key}=#{value}" }
        .join(", ")
    end

    def derivation_options
      shrine_class.derivation_options.merge(self.options)
    end
  end

  class Derivation::Response < Derivation::Command
    delegate :type, :disposition, :filename,
             :upload, :upload_redirect, :upload_redirect_url_options

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

    def file_response(file, env)
      file.close
      response = rack_file_response(file.path, env)

      status = response[0]

      filename  = self.filename
      filename += File.extname(file.path) if File.extname(filename).empty?

      headers = {}
      headers["Content-Type"]        = type || response[1]["Content-Type"]
      headers["Content-Disposition"] = content_disposition(filename)
      headers["Content-Length"]      = response[1]["Content-Length"]
      headers["Content-Range"]       = response[1]["Content-Range"] if response[1]["Content-Range"]
      headers["Accept-Ranges"]       = "bytes"

      body = Rack::BodyProxy.new(response[2]) { File.delete(file.path) }

      [status, headers, body]
    end

    def upload_response(env)
      uploaded_file = derivation.retrieve

      unless uploaded_file
        derivative    = derivation.generate
        uploaded_file = derivation.upload(derivative)
      end

      if upload_redirect
        File.delete(derivative.path) if derivative

        redirect_url = uploaded_file.url(upload_redirect_url_options)

        [302, { "Location" => redirect_url }, []]
      else
        if derivative
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

    def rack_file_response(path, env)
      server = Rack::File.new("", {}, "application/octet-stream")

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
  end

  class Derivation::Processed < Derivation::Command
    delegate :upload

    def call
      if upload
        upload_result
      else
        local_result
      end
    end

    private

    def local_result
      derivation.generate
    end

    def upload_result
      uploaded_file = derivation.retrieve

      unless uploaded_file
        derivative    = derivation.generate
        uploaded_file = derivation.upload(derivative)

        derivative.unlink
      end

      uploaded_file
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

    def download_source
      download_args = download_options.any? ? [download_options] : []
      downloaded    = false

      source.download(*download_args) do |file|
        downloaded = true
        yield file
      end
    rescue *download_errors
      raise if downloaded # re-raise if the error didn't happen on download
      raise Derivation::SourceNotFound, "source file \"#{source.id}\" was not found on storage :#{source.storage_key}"
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

    def call(derivative = nil)
      derivative ||= derivation.generate

      uploader.upload derivative,
        location:       upload_location,
        upload_options: upload_options
    end

    private

    def uploader
      shrine_class.new(upload_storage)
    end
  end

  class Derivation::Retrieve < Derivation::Command
    delegate :upload_location, :upload_storage

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
        fail InvalidSignature, "missing \"signature\" param"
      elsif signature != generate_signature(string)
        fail InvalidSignature, "provided signature does not match the calculated signature"
      end
    end

    def generate_signature(string)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, secret_key, string)
    end
  end
end
