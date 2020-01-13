require "test_helper"
require "shrine/storage/s3"
require "shrine/storage/linter"

describe Shrine::Storage::Memory do
  before do
    @memory = Shrine::Storage::Memory.new
  end

  it "passes the linter" do
    assert Shrine::Storage::Linter.call(@memory)
  end


  # work around apparent bug in ruby 2.7.0
  # https://bugs.ruby-lang.org/issues/16497
  it "preserves encoding despite Encoding.default_internal set" do
    begin
      original = Encoding.default_internal
      Encoding.default_internal = Encoding::UTF_8

      binary_string = "\x99".force_encoding("ASCII-8BIT")
      @memory.upload(StringIO.new(binary_string, "r:ASCII-8BIT"), "key")
      assert_equal @memory.open("key").read.encoding, Encoding::BINARY
    ensure
      Encoding.default_internal = original
    end
  end
end
