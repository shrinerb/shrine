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

  describe "#upload" do
    it "accepts keyword arguments" do
      @memory.upload(fakeio, "key", foo: "bar")
    end
  end

  describe "#open" do
    it "accepts keyword arguments" do
      @memory.upload(fakeio, "key")
      @memory.open("key", foo: "bar")
    end
  end

  # work around apparent bug in ruby 2.7.0
  # https://bugs.ruby-lang.org/issues/16497
  it "preserves encoding despite Encoding.default_internal set" do
    @memory.upload(fakeio("content".b), "key")

    begin
      original_internal = Encoding.default_internal
      Encoding.default_internal = Encoding::UTF_8

      assert_equal Encoding::BINARY, @memory.open("key").read.encoding
    ensure
      Encoding.default_internal = original_internal
    end
  end
end
