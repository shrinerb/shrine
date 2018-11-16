# frozen_string_literal: true

require "base64"
require "json"
require "openssl"

class Shrine
  module Plugins
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

        if RUBY_VERSION >= "2.3"
          def base64_encode(data)
            Base64.urlsafe_encode64(data, padding: false)
          end
        else
          def base64_encode(data)
            Base64.urlsafe_encode64(data)
          end
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

    register_plugin(:urlsafe_serialization, UrlsafeSerialization)
  end
end
