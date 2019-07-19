require "test_helper"
require "shrine/plugins/rack_file"
require "tempfile"

describe Shrine::Plugins::RackFile do
  before do
    @attacher  = attacher { plugin :rack_file }
    @shrine    = @attacher.shrine_class
    @rack_hash = {
      name: "file",
      tempfile: Tempfile.new,
      filename: "image.jpg",
      type: "image/jpeg",
      head: "...",
    }
  end

  it "allows converting Rack file hash into an IO object" do
    rack_file = @shrine.rack_file(@rack_hash)

    assert_equal "",   rack_file.read
    assert_equal 0,    rack_file.size
    assert_equal true, rack_file.eof?

    rack_file.rewind
    rack_file.close
  end

  it "exposes metadata on the IO object" do
    rack_file = @shrine.rack_file(@rack_hash)

    assert_equal 0,                          rack_file.size
    assert_equal "image.jpg",                rack_file.original_filename
    assert_equal "image/jpeg",               rack_file.content_type
  end

  it "adds methods for accessing the Tempfile" do
    rack_file = @shrine.rack_file(@rack_hash)

    assert_equal @rack_hash[:tempfile],      rack_file.tempfile
    assert_equal @rack_hash[:tempfile],      rack_file.to_io
    assert_equal @rack_hash[:tempfile].path, rack_file.path
  end

  it "accepts hash-like parameters" do
    hash_like_class = Class.new(Hash) do
      def initialize(hash)
        @hash = hash.inject({}) { |h, (key, value)| h.update(key.to_s => value) }
      end

      def key?(name)
        @hash.key?(name.to_s)
      end

      def [](name)
        @hash[name.to_s]
      end
    end

    rack_file = @shrine.rack_file(hash_like_class.new(@rack_hash))

    assert_equal 0,            rack_file.size
    assert_equal "image.jpg",  rack_file.original_filename
    assert_equal "image/jpeg", rack_file.content_type
  end

  it "converts filename from binary encoding to utf-8" do
    @rack_hash[:filename] = "über_pdf_with_1337%_leetness.pdf".b

    rack_file = @shrine.rack_file(@rack_hash)

    assert_equal Encoding::UTF_8, rack_file.original_filename.encoding
    assert_equal Encoding::BINARY, @rack_hash[:filename].encoding
  end

  it "supports attaching Rack files directly" do
    @attacher.assign(@rack_hash)

    assert_equal "",           @attacher.get.read
    assert_equal 0,            @attacher.get.size
    assert_equal "image.jpg",  @attacher.get.original_filename
    assert_equal "image/jpeg", @attacher.get.mime_type
  end

  it "accepts assign options" do
    @attacher.assign(@rack_hash, metadata: { "foo" => "bar" })
    assert_equal "bar", @attacher.get.metadata["foo"]
    @attacher.assign(fakeio, metadata: { "foo" => "bar" })
    assert_equal "bar", @attacher.get.metadata["foo"]
  end
end
