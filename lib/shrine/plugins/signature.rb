# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/signature
    module Signature
      LOG_SUBSCRIBER = -> (event) do
        Shrine.logger.info "Signature (#{event.duration}ms) – #{{
          io:        event[:io].class,
          algorithm: event[:algorithm],
          format:    event[:format],
          uploader:  event[:uploader],
        }.inspect}"
      end

      def self.configure(uploader, log_subscriber: LOG_SUBSCRIBER)
        # instrumentation plugin integration
        uploader.subscribe(:signature, &log_subscriber) if uploader.respond_to?(:subscribe)
      end

      module ClassMethods
        # Calculates `algorithm` hash of the contents of the IO object, and
        # encodes it into `format`.
        def calculate_signature(io, algorithm, format: :hex)
          instrument_signature(io, algorithm, format) do
            SignatureCalculator.new(algorithm.downcase, format: format).call(io)
          end
        end
        alias signature calculate_signature

        private

        # Sends a `signature.shrine` event for instrumentation plugin.
        def instrument_signature(io, algorithm, format, &block)
          return yield unless respond_to?(:instrument)

          instrument(:signature, io: io, algorithm: algorithm, format: format, &block)
        end
      end

      module InstanceMethods
        # Calculates `algorithm` hash of the contents of the IO object, and
        # encodes it into `format`.
        def calculate_signature(io, algorithm, format: :hex)
          self.class.calculate_signature(io, algorithm, format: format)
        end
      end

      class SignatureCalculator
        SUPPORTED_ALGORITHMS = [:sha1, :sha256, :sha384, :sha512, :md5, :crc32]
        SUPPORTED_FORMATS    = [:none, :hex, :base64]

        attr_reader :algorithm, :format

        def initialize(algorithm, format:)
          raise Error, "unknown hash algorithm #{algorithm.inspect}, supported algorithms are: #{SUPPORTED_ALGORITHMS.join(",")}" unless SUPPORTED_ALGORITHMS.include?(algorithm)
          raise Error, "unknown hash format #{format.inspect}, supported formats are: #{SUPPORTED_FORMATS.join(",")}" unless SUPPORTED_FORMATS.include?(format)

          @algorithm = algorithm
          @format    = format
        end

        def call(io)
          hash = send(:"calculate_#{algorithm}", io)
          io.rewind

          send(:"encode_#{format}", hash)
        end

        private

        def calculate_sha1(io)
          calculate_digest(:SHA1, io)
        end

        def calculate_sha256(io)
          calculate_digest(:SHA256, io)
        end

        def calculate_sha384(io)
          calculate_digest(:SHA384, io)
        end

        def calculate_sha512(io)
          calculate_digest(:SHA512, io)
        end

        def calculate_md5(io)
          calculate_digest(:MD5, io)
        end

        def calculate_crc32(io)
          require "zlib"
          crc = 0
          crc = Zlib.crc32(io.read(16*1024, buffer ||= String.new), crc) until io.eof?
          crc.to_s
        end

        def calculate_digest(name, io)
          require "digest"
          digest = Digest.const_get(name).new
          digest.update(io.read(16*1024, buffer ||= String.new)) until io.eof?
          digest.digest
        end

        def encode_none(hash)
          hash
        end

        def encode_hex(hash)
          hash.unpack("H*").first
        end

        def encode_base64(hash)
          require "base64"
          Base64.strict_encode64(hash)
        end
      end

      SUPPORTED_ALGORITHMS = SignatureCalculator::SUPPORTED_ALGORITHMS
      SUPPORTED_FORMATS    = SignatureCalculator::SUPPORTED_FORMATS
    end

    register_plugin(:signature, Signature)
  end
end
