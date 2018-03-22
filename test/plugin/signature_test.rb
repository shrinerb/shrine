require "test_helper"
require "shrine/plugins/signature"
require "digest"
require "zlib"

describe Shrine::Plugins::Signature do
  before do
    @uploader = uploader { plugin :signature }
  end

  supported_algorithms = Shrine::Plugins::Signature::SUPPORTED_ALGORITHMS
  supported_formats    = Shrine::Plugins::Signature::SUPPORTED_FORMATS

  supported_algorithms.each do |algorithm|
    it "can generate a #{algorithm.to_s.upcase} hash from a file" do
      io = fakeio("content")

      supported_formats.each do |format|
        hash = @uploader.calculate_signature(io, algorithm, format: format)
        assert_instance_of String, hash
        refute hash.empty?
        refute io.eof?
      end
    end

    it "can generate a #{algorithm.to_s.upcase} hash from an empty file" do
      io = fakeio("")

      supported_formats.each do |format|
        hash = @uploader.calculate_signature(io, algorithm, format: format)
        assert_instance_of String, hash
        refute hash.empty?
      end
    end
  end

  it "generates correct signature from the IO object" do
    content = "a" * 40*1024
    io = fakeio(content)

    assert_equal Digest::MD5.digest(content),          @uploader.calculate_signature(io, :md5,    format: :none)
    assert_equal Digest::MD5.hexdigest(content),       @uploader.calculate_signature(io, :md5,    format: :hex)
    assert_equal Digest::MD5.base64digest(content),    @uploader.calculate_signature(io, :md5,    format: :base64)

    assert_equal Digest::SHA1.digest(content),         @uploader.calculate_signature(io, :sha1,   format: :none)
    assert_equal Digest::SHA1.hexdigest(content),      @uploader.calculate_signature(io, :sha1,   format: :hex)
    assert_equal Digest::SHA1.base64digest(content),   @uploader.calculate_signature(io, :sha1,   format: :base64)

    assert_equal Digest::SHA256.digest(content),       @uploader.calculate_signature(io, :sha256, format: :none)
    assert_equal Digest::SHA256.hexdigest(content),    @uploader.calculate_signature(io, :sha256, format: :hex)
    assert_equal Digest::SHA256.base64digest(content), @uploader.calculate_signature(io, :sha256, format: :base64)

    assert_equal Digest::SHA384.digest(content),       @uploader.calculate_signature(io, :sha384, format: :none)
    assert_equal Digest::SHA384.hexdigest(content),    @uploader.calculate_signature(io, :sha384, format: :hex)
    assert_equal Digest::SHA384.base64digest(content), @uploader.calculate_signature(io, :sha384, format: :base64)

    assert_equal Digest::SHA512.digest(content),       @uploader.calculate_signature(io, :sha512, format: :none)
    assert_equal Digest::SHA512.hexdigest(content),    @uploader.calculate_signature(io, :sha512, format: :hex)
    assert_equal Digest::SHA512.base64digest(content), @uploader.calculate_signature(io, :sha512, format: :base64)

    assert_equal Zlib.crc32(content).to_s,             @uploader.calculate_signature(io, :crc32,  format: :none)
  end

  it "defaults hash format to hexadecimal" do
    assert_match /^[[:alnum:]]+$/, @uploader.calculate_signature(fakeio("content"), :md5)
  end

  it "accepts uppercase algorithm names" do
    assert_instance_of String, @uploader.calculate_signature(fakeio("content"), :MD5)
  end

  it "raises an error on unsupported hash algorithm" do
    assert_raises(Shrine::Error) { @uploader.calculate_signature(fakeio, :unknown) }
  end

  it "raises an error on unsupported hash format" do
    assert_raises(Shrine::Error) { @uploader.calculate_signature(fakeio, :md5, format: :unknown) }
  end

  it "can calculate hash both from instance and class level" do
    assert_instance_of String, @uploader.calculate_signature(fakeio, :md5)
    assert_instance_of String, @uploader.class.calculate_signature(fakeio, :md5)
  end
end
