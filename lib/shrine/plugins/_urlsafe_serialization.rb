# frozen_string_literal: true

require "base64"
require "json"
require "openssl"

class Shrine
  module Plugins
    # The `urlsafe_serialization` plugin provides the ability to serialize and
    # deserialize a `Shrine::UploadedFile` in a way that's suitable for
    # including in a URL.
    #
    #     plugin :urlsafe_serialization
    #
    # The plugin defines `urlsafe_dump` and `urlsafe_load` methods on
    # `Shrine::UploadedFile`. The file is first serialized to JSON, then
    # encoded with base64.
    #
    #     serialized = uploaded_file.urlsafe_dump
    #     # or
    #     serialized = MyUploader::UploadedFile.urlsafe_dump(uploaded_file)
    #     serialized #=> "eyJpZCI6IjlhZGM0NmIzZjI..."
    #
    #     # ...
    #
    #     uploaded_file = MyUploader::UploadedFile.urlsafe_load(serialized)
    #     uploaded_file #=> #<MyUploader::UploadedFile>
    #
    # ## Metadata
    #
    # By default no metadata is included in the serialization:
    #
    #     uploaded_file.metadata #=> { ... metadata ... }
    #
    #     serialized    = MyUploader::UploadedFile.urlsafe_dump(uploaded_file)
    #     uploaded_file = MyUploader::UploadedFile.urlsafe_load(serialized)
    #
    #     uploaded_file.metadata #=> {}
    #
    # The `:metadata` option can be used to specify metadata you want to
    # serialize:
    #
    #     serialized    = MyUploader::UploadedFile.urlsafe_dump(uploaded_file, metadata: %w[size mime_type])
    #     uploaded_file = MyUploader::UploadedFile.urlsafe_load(serialized)
    #
    #     uploaded_file.metadata #=> { "size" => 4394, "mime_type" => "image/jpeg" }
    #
    # ## Signing
    #
    # By default the seralization is done with simple JSON + base64 encoding.
    # If you want to ensure the serialized data hasn't been tampred with, you
    # can have it signed with a secret key.
    #
    #     plugin :urlsafe_serialization, secret_key: "my secret key"
    #
    # Now the `urlsafe_dump` will automatically sign serialized data with your
    # secret key, and `urlsafe_load` will automatically verify it.
    #
    #     serialized = MyUploader::UploadedFile.urlsafe_dump(uploaded_file)
    #     serialized #=> "<signature>--<json-base64-encoded-data>"
    #
    #     uploaded_file = MyUploader::UploadedFile.urlsafe_load(serialized) # verifies the signature
    #     uploaded_file #=> #<MyUploader::UploadedFile>
    #
    # If the signature is missing or invalid,
    # `Shrine::Plugins::UrlsafeSerialization::InvalidSignature` exception is
    # raised.
    module UrlsafeSerialization
      class InvalidSignature < Error; end

      def self.configure(uploader, opts = {})
        uploader.opts[:urlsafe_serialization] ||= {}
        uploader.opts[:urlsafe_serialization].merge!(opts)
      end

      module FileMethods
        def urlsafe_dump(**options)
          self.class.urlsafe_dump(self, **options)
        end
      end

      module FileClassMethods
        def urlsafe_dump(file, metadata: [])
          data = file.data.dup
          data["metadata"] = metadata
            .map { |name| [name, file.metadata[name]] }
            .to_h

          urlsafe_serializer.dump(data)
        end

        def urlsafe_load(string)
          data = urlsafe_serializer.load(string)

          new(data)
        end

        def urlsafe_serializer
          secret_key = shrine_class.opts[:urlsafe_serialization][:secret_key]

          if secret_key
            SecureSerializer.new(secret_key: secret_key)
          else
            Serializer.new
          end
        end
      end

      class Serializer
        def dump(data)
          base64_encode(json_encode(data))
        end

        def load(data)
          json_decode(base64_decode(data))
        end

        private

        def json_encode(data)
          JSON.generate(data)
        end

        def base64_encode(data)
          Base64.urlsafe_encode64(data, padding: false)
        end

        def base64_decode(data)
          Base64.urlsafe_decode64(data)
        end

        def json_decode(data)
          JSON.parse(data)
        end
      end

      class SecureSerializer < Serializer
        attr_reader :secret_key

        def initialize(secret_key:)
          @secret_key = secret_key
        end

        def dump(data)
          hmac_encode(super)
        end

        def load(data)
          super(hmac_decode(data))
        end

        def hmac_encode(data)
          "#{generate_hmac(data)}--#{data}"
        end

        def hmac_decode(data)
          data, hmac = data.split("--", 2).reverse
          verify_hmac(hmac, data)
          data
        end

        def verify_hmac(provided_hmac, data)
          if provided_hmac.nil?
            raise InvalidSignature, "signature is missing"
          end

          expected_hmac = generate_hmac(data)

          if provided_hmac != expected_hmac
            raise InvalidSignature, "provided signature doesn't match the expected"
          end
        end

        def generate_hmac(data)
          OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, secret_key, data)
        end
      end
    end

    register_plugin(:_urlsafe_serialization, UrlsafeSerialization)
  end
end
