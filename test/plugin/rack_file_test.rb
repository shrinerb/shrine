require "test_helper"
require "shrine/plugins/rack_file"
require "down"
require "delegate"

describe Shrine::Plugins::RackFile do
  before do
    @uploader = uploader { plugin :rack_file }
    @rack_file = {
      name: "file",
      tempfile: Down.copy_to_tempfile("", fakeio("image")),
      filename: "image.jpg",
      type: "image/jpeg",
      head: "...",
    }
  end

  it "enables assignment of Rack file hashes" do
    uploaded_file = @uploader.upload(@rack_file)

    assert_equal "image",      uploaded_file.read
    assert_equal 5,            uploaded_file.size
    assert_equal "image.jpg",  uploaded_file.original_filename
    assert_equal "image/jpeg", uploaded_file.mime_type
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
    uploaded_file = @uploader.upload(hash_like_object)

    assert_equal "image",      uploaded_file.read
    assert_equal 5,            uploaded_file.size
    assert_equal "image.jpg",  uploaded_file.original_filename
    assert_equal "image/jpeg", uploaded_file.mime_type
  end

  it "adds #path, #to_io and #tempfile methods to IO" do
    @uploader.instance_eval { def process(io, context) @rack_file = io end }
    uploaded_file = @uploader.upload(@rack_file)
    rack_file = @uploader.instance_variable_get("@rack_file")

    assert_equal @rack_file[:tempfile].path, rack_file.path
    assert_equal @rack_file[:tempfile],      rack_file.to_io
    assert_equal @rack_file[:tempfile],      rack_file.tempfile
  end

  it "works with attacher" do
    @attacher = attacher { plugin :rack_file }
    @attacher.assign(@rack_file)

    assert_equal "image",      @attacher.get.read
    assert_equal 5,            @attacher.get.size
    assert_equal "image.jpg",  @attacher.get.original_filename
    assert_equal "image/jpeg", @attacher.get.mime_type
  end
end
