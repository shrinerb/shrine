require "test_helper"
require "shrine/plugins/rack_file"

describe Shrine::Plugins::RackFile do
  before do
    @attacher = attacher { plugin :rack_file }
  end

  it "enables assignment of Rack file hashes" do
    @attacher.assign({
      tempfile: fakeio("image"),
      filename: "image.jpg",
      type: "image/jpeg",
      head: "...",
    })
    uploaded_file = @attacher.get
    assert_equal "image",      uploaded_file.read
    assert_equal 5,            uploaded_file.size
    assert_equal "image.jpg",  uploaded_file.original_filename
    assert_equal "image/jpeg", uploaded_file.mime_type
  end

  it "adds #path, #to_io and #tempfile methods to IO" do
    @attacher.cache.instance_eval do
      def upload(io, context = {})
        @rack_file = io
        super
      end
    end
    @attacher.assign({tempfile: tempfile = Tempfile.new("")})
    rack_file = @attacher.cache.instance_variable_get("@rack_file")
    refute_empty rack_file.path
    assert_equal tempfile, rack_file.to_io
    assert_equal tempfile, rack_file.tempfile
  end
end
