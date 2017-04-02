require "test_helper"
require "shrine/plugins/signature"

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
  end

  it "can calculate hash both from instance and class level" do
    assert_instance_of String, @uploader.calculate_signature(fakeio, :md5)
    assert_instance_of String, @uploader.class.calculate_signature(fakeio, :md5)
  end

  it "defaults hash format to hexadecimal" do
    assert_match /^[[:alnum:]]+$/, @uploader.calculate_signature(fakeio("content"), :md5)
  end

  it "accepts uppercase algorithm names" do
    assert_instance_of String, @uploader.calculate_signature(fakeio("content"), :MD5)
  end

  it "raises an error on unsupported hash algorithm" do
    assert_raises(ArgumentError) { @uploader.calculate_signature(fakeio, :unknown) }
  end

  it "raises an error on unsupported hash format" do
    assert_raises(ArgumentError) { @uploader.calculate_signature(fakeio, :md5, format: :unknown) }
  end
end
