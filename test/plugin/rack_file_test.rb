require "test_helper"

describe "the rack_file plugin" do
  before do
    @attacher = attacher { plugin :rack_file }
  end

  it "enables assignment of Rack file hashes" do
    uploaded_file = @attacher.assign({
      tempfile: fakeio("image"),
      filename: "image.jpg",
      type: "image/jpeg",
      head: "...",
    })
    assert_equal "image",      uploaded_file.read
    assert_equal 5,            uploaded_file.size
    assert_equal "image.jpg",  uploaded_file.original_filename
    assert_equal "image/jpeg", uploaded_file.mime_type
  end

  it "adds #path, #to_io and #tempfile methods to IO" do
    @attacher.cache.instance_eval do
      def process(io, context)
        io.path
        io.to_io
        io.tempfile
      end
    end

    @attacher.assign({tempfile: Tempfile.new("")})
  end
end
