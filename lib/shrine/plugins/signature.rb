class Shrine
  module Plugins
    # The `signature` plugin provides the ability to calculate a hash from file
    # content. The hash can then be used as a checksum or just as a unique
    # signature of the file.
    #
    #     plugin :signature
    #
    # The plugin adds a `calculate_signature` instance and class method to
    # `Shrine`, which accepts the IO object and hashing algorithm and returns
    # the calculated hash.
    #
    #     Shrine.calculate_signature(io, :md5)
    #     #=> "9a0364b9e99bb480dd25e1f0284c8555"
    #
    # You can then use the `add_metadata` plugin to add a new metadata field
    # with the calculated hash.
    #
    #     plugin :add_metadata
    #
    #     add_metadata :md5 do |io, context|
    #       calculate_signature(io, :md5)
    #     end
    #
    # This will generate a hash for each uploaded file, but if you want to
    # generate one only for the original file, you can add a conditional:
    #
    #     add_metadata :md5 do |io, context|
    #       calculate_signature(io, :md5) if context[:action] == :cache
    #     end
    #
    # The following hashing algorithms are supported:
    #
    # * `sha1`
    # * `sha256`
    # * `sha384`
    # * `sha512`
    # * `md5`
    # * `crc32`
    #
    # You can also choose which format will the calculated hash be encoded in:
    #
    #     Shrine.calculate_signature(io, :md5, format: :hex)
    #
    # The following encoding formats are supported:
    #
    # * `none`
    # * `hex` (default)
    # * `base64`
    module Signature
      module ClassMethods
        # Calculates `algorithm` hash of the contents of the IO object, and
        # encodes it into `format`.
        def calculate_signature(io, algorithm, format: :hex)
          algorithm = algorithm.downcase # support uppercase algorithm names like :MD5
          SignatureCalculator.new(algorithm, format: format).call(io)
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
          raise ArgumentError, "hash algorithm not supported: #{algorithm}" unless SUPPORTED_ALGORITHMS.include?(algorithm)
          raise ArgumentError, "hash format not supported: #{format}" unless SUPPORTED_FORMATS.include?(format)

          @algorithm = algorithm
          @format    = format
        end

        def call(io)
          hash = send(:"calculate_#{algorithm}", io)
          io.rewind

          encoded_hash = send(:"encode_#{format}", hash)
          encoded_hash
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
          crc = Zlib.crc32(io.read(16*1024, buffer ||= ""), crc) until io.eof?
          crc.to_s
        end

        def calculate_digest(name, io)
          require "digest"
          digest = Digest.const_get(name).new
          digest.update(io.read(16*1024, buffer ||= "")) until io.eof?
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
          Base64.encode64(hash)
        end
      end

      SUPPORTED_ALGORITHMS = SignatureCalculator::SUPPORTED_ALGORITHMS
      SUPPORTED_FORMATS    = SignatureCalculator::SUPPORTED_FORMATS
    end

    register_plugin(:signature, Signature)
  end
end
