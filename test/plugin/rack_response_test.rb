require "test_helper"
require "shrine/plugins/rack_response"
require "shrine/storage/file_system"

describe Shrine::Plugins::RackResponse do
  before do
    @uploader = uploader { plugin :rack_response }
    @shrine   = @uploader.class
  end

  it "returns 200 status" do
    uploaded_file = @uploader.upload(fakeio("content"))
    response = uploaded_file.to_rack_response
    assert_equal 200, response[0]
  end

  it "returns Content-Length header with size if metadata is missing" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.metadata.delete("size")
    response = uploaded_file.to_rack_response
    assert_equal "7", response[1]["Content-Length"]
  end

  it "returns Content-Type header with mime_type metadata" do
    uploaded_file = @uploader.upload(fakeio(content_type: "text/plain"))
    response = uploaded_file.to_rack_response
    assert_equal "text/plain", response[1]["Content-Type"]
  end

  it "returns Content-Type header from extension if mime_type metadata is missing" do
    uploaded_file = @uploader.upload(fakeio(filename: "document.txt"))
    response = uploaded_file.to_rack_response
    assert_equal "text/plain", response[1]["Content-Type"]
  end

  it "doesn't return Content-Type header if MIME type is unknown" do
    uploaded_file = @uploader.upload(fakeio(filename: "foo.foo"))
    response = uploaded_file.to_rack_response
    refute response[1].key?("Content-Type")
  end

  it "doesn't Content-Type header if MIME type is missing" do
    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response
    refute response[1].key?("Content-Type")
  end

  it "returns Content-Type header from :type" do
    uploaded_file = @uploader.upload(fakeio(content_type: "text/plain"))
    response = uploaded_file.to_rack_response(type: "text/plain; charset=utf-8")
    assert_equal "text/plain; charset=utf-8", response[1]["Content-Type"]
  end

  it "it allows setting Content-Type to application/octet-stream" do
    uploaded_file = @uploader.upload(fakeio(content_type: "application/octet-stream"))
    response = uploaded_file.to_rack_response
    assert_equal "application/octet-stream", response[1]["Content-Type"]

    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response(type: "application/octet-stream")
    assert_equal "application/octet-stream", response[1]["Content-Type"]
  end

  it "returns Content-Disposition filename from metadata" do
    uploaded_file = @uploader.upload(fakeio(filename: "plain.txt"))
    response = uploaded_file.to_rack_response
    assert_equal ContentDisposition.inline("plain.txt"), response[1]["Content-Disposition"]
  end

  it "returns Content-Disposition filename from :filename" do
    uploaded_file = @uploader.upload(fakeio(filename: "plain.txt"))
    response = uploaded_file.to_rack_response(filename: "custom.txt")
    assert_equal ContentDisposition.inline("custom.txt"), response[1]["Content-Disposition"]
  end

  it "returns Content-Disposition filename with id if metadata is missing" do
    uploaded_file = @uploader.upload(fakeio, location: "foo/bar/baz")
    response = uploaded_file.to_rack_response
    assert_equal ContentDisposition.inline("baz"), response[1]["Content-Disposition"]
  end

  it "returns Content-Disposition disposition from :disposition" do
    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response(disposition: "attachment")
    assert_equal ContentDisposition.attachment(uploaded_file.id), response[1]["Content-Disposition"]
  end

  it "returns body which yields contents of the file" do
    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    response = uploaded_file.to_rack_response
    yielded_content = []
    response[2].each { |chunk| yielded_content << chunk }
    assert_equal ["a" * 16*1024, "b" * 16*1024, "c" * 4*1024], yielded_content
  end

  it "calls #each_chunk on Down::ChunkedIO when generating body" do
    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    uploaded_file.to_io.instance_eval { def each_chunk; yield read; end }
    response = uploaded_file.to_rack_response
    yielded_content = []
    response[2].each { |chunk| yielded_content << chunk }
    assert_equal ["a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024], yielded_content
  end

  it "closes the file when response is closed" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.open
    response = uploaded_file.to_rack_response

    existing_io = uploaded_file.to_io

    response[2].close
    assert existing_io.closed?
  end

  it "returns ranged responses when :range is given" do
    uploaded_file = @uploader.upload(fakeio("content"))
    response = uploaded_file.to_rack_response(range: "bytes=0-6")
    assert_equal 206,           response[0]
    assert_equal "bytes 0-6/7", response[1]["Content-Range"]
    assert_equal "7",           response[1]["Content-Length"]
    assert_equal "content",     response[2].each { |chunk| break chunk }

    uploaded_file = @uploader.upload(fakeio("content"))
    response = uploaded_file.to_rack_response(range: "bytes=0-2")
    assert_equal 206,           response[0]
    assert_equal "bytes 0-2/7", response[1]["Content-Range"]
    assert_equal "3",           response[1]["Content-Length"]
    assert_equal "con",         response[2].each { |chunk| break chunk }

    uploaded_file = @uploader.upload(fakeio("content"))
    response = uploaded_file.to_rack_response(range: "bytes=2-4")
    assert_equal 206,           response[0]
    assert_equal "bytes 2-4/7", response[1]["Content-Range"]
    assert_equal "3",           response[1]["Content-Length"]
    assert_equal "nte",         response[2].each { |chunk| break chunk }

    uploaded_file = @uploader.upload(fakeio("content"))
    response = uploaded_file.to_rack_response(range: "bytes=4-6")
    assert_equal 206,           response[0]
    assert_equal "bytes 4-6/7", response[1]["Content-Range"]
    assert_equal "3",           response[1]["Content-Length"]
    assert_equal "ent",         response[2].each { |chunk| break chunk }
  end

  it "returns ranged responses across multiple chunks" do
    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    response = uploaded_file.to_rack_response(range: "bytes=0-36863")
    assert_equal "bytes 0-36863/36864", response[1]["Content-Range"]
    assert_equal "36864",               response[1]["Content-Length"]
    yielded_content = String.new
    response[2].each { |chunk| yielded_content << chunk }
    assert_equal "a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024, yielded_content

    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    response = uploaded_file.to_rack_response(range: "bytes=0-20479")
    assert_equal "bytes 0-20479/36864", response[1]["Content-Range"]
    assert_equal "20480",               response[1]["Content-Length"]
    yielded_content = String.new
    response[2].each { |chunk| yielded_content << chunk }
    assert_equal "a" * 16*1024 + "b" * 4*1024, yielded_content

    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    response = uploaded_file.to_rack_response(range: "bytes=12288-20479")
    assert_equal "bytes 12288-20479/36864", response[1]["Content-Range"]
    assert_equal "8192", response[1]["Content-Length"]
    yielded_content = String.new
    response[2].each { |chunk| yielded_content << chunk }
    assert_equal "a" * 4*1024 + "b" * 4*1024, yielded_content

    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    response = uploaded_file.to_rack_response(range: "bytes=12288-33791")
    assert_equal "bytes 12288-33791/36864", response[1]["Content-Range"]
    assert_equal "21504", response[1]["Content-Length"]
    yielded_content = String.new
    response[2].each { |chunk| yielded_content << chunk }
    assert_equal "a" * 4*1024 + "b" * 16*1024 + "c" * 1*1024, yielded_content

    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    response = uploaded_file.to_rack_response(range: "bytes=35840-36863")
    assert_equal "bytes 35840-36863/36864", response[1]["Content-Range"]
    assert_equal "1024", response[1]["Content-Length"]
    yielded_content = String.new
    response[2].each { |chunk| yielded_content << chunk }
    assert_equal "c" * 1*1024, yielded_content
  end

  it "returns correct ranged response even when size metadata is missing" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.metadata.delete("size")
    response = uploaded_file.to_rack_response(range: "bytes=0-6")
    assert_equal 206,           response[0]
    assert_equal "bytes 0-6/7", response[1]["Content-Range"]
    assert_equal "7",           response[1]["Content-Length"]
    assert_equal "content",     response[2].each { |chunk| break chunk }
  end

  it "returns Accept-Ranges when :range is given" do
    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response
    refute response[1].key?("Accept-Ranges")
    response = uploaded_file.to_rack_response(range: nil)
    assert_equal "bytes", response[1]["Accept-Ranges"]
  end

  it "returns ETag" do
    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response
    assert_instance_of String,    response[1]["ETag"]
    assert_match /^W\/"\w{32}"$/, response[1]["ETag"]
  end

  it "makes ETag as unique as possible" do
    etags = []

    etags << @uploader.class.new(:cache)
      .upload(fakeio, location: "foo")
      .to_rack_response[1]["ETag"]

    etags << @uploader.class.new(:cache)
      .upload(fakeio, location: "bar")
      .to_rack_response[1]["ETag"]

    etags << @uploader.class.new(:store)
      .upload(fakeio, location: "foo")
      .to_rack_response[1]["ETag"]

    etags << uploader { plugin :rack_response }
      .upload(fakeio, location: "foo")
      .to_rack_response[1]["ETag"]

    assert_equal etags, etags.uniq
  end

  it "implements #to_path on the body for filesystem storage" do
    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response
    refute_respond_to response[2], :to_path
    assert_raises(NoMethodError) { response[2].to_path }

    @shrine.storages[:disk] = Shrine::Storage::FileSystem.new(Dir.tmpdir)
    @uploader = @shrine.new(:disk)
    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response
    assert_respond_to response[2], :to_path
    assert_equal @uploader.storage.path(uploaded_file.id), response[2].to_path
  end
end
