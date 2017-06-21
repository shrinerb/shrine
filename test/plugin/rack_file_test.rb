require "test_helper"
require "shrine/plugins/rack_file"
require "tempfile"

describe Shrine::Plugins::RackFile do
  before do
    @attacher = attacher { plugin :rack_file }
    @rack_file = {
      name: "file",
      tempfile: Tempfile.new(""),
      filename: "image.jpg",
      type: "image/jpeg",
      head: "...",
    }
  end

  it "enables assignment of Rack file hashes" do
    @attacher.assign(@rack_file)
    cached_file = @attacher.get

    assert_equal "",           cached_file.read
    assert_equal 0,            cached_file.size
    assert_equal "image.jpg",  cached_file.original_filename
    assert_equal "image/jpeg", cached_file.mime_type
  end

  it "accepts hash with indifferent access like objects" do
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

    hash_like_object = hash_like_class.new(@rack_file)
    @attacher.assign(hash_like_object)
    cached_file = @attacher.get

    assert_equal "",           cached_file.read
    assert_equal 0,            cached_file.size
    assert_equal "image.jpg",  cached_file.original_filename
    assert_equal "image/jpeg", cached_file.mime_type
  end

  it "adds #path, #to_io and #tempfile methods to IO" do
    @attacher.cache.instance_eval { def process(io, context) @rack_file = io end }
    @attacher.assign(@rack_file)
    rack_file = @attacher.cache.instance_variable_get("@rack_file")

    assert_equal @rack_file[:tempfile].path, rack_file.path
    assert_equal @rack_file[:tempfile],      rack_file.to_io
    assert_equal @rack_file[:tempfile],      rack_file.tempfile
  end

  deprecated "works with uploader" do
    uploaded_file = @attacher.store.upload(@rack_file)

    assert_equal "",           uploaded_file.read
    assert_equal 0,            uploaded_file.size
    assert_equal "image.jpg",  uploaded_file.original_filename
    assert_equal "image/jpeg", uploaded_file.mime_type
  end
end
