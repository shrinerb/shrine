require "test_helper"
require "stringio"

describe "the determine_mime_type plugin" do
  describe ":file" do
    before do
      @uploader = uploader { plugin :determine_mime_type, analyzer: :file }
    end

    it "determines content type from file contents" do
      mime_type = @uploader.send(:extract_mime_type, image)
      assert_equal "image/jpeg", mime_type
    end

    it "is able to determine content type for non-files" do
      mime_type = @uploader.send(:extract_mime_type, fakeio(image.read))
      assert_equal "image/jpeg", mime_type
    end

    it "handles filenames which start with '-' and look like an option" do
      FileUtils.cp(image, "-image.jpg")
      dashed_image = File.open("-image.jpg")
      mime_type = @uploader.send(:extract_mime_type, dashed_image)
      assert_equal "image/jpeg", mime_type
      FileUtils.rm("-image.jpg")
    end
  end

  describe ":filemagic" do
    before do
      @uploader = uploader { plugin :determine_mime_type, analyzer: :filemagic }
    end

    it "determines content type from file contents" do
      mime_type = @uploader.send(:extract_mime_type, image)
      assert_equal "image/jpeg", mime_type
    end
  end unless RUBY_ENGINE == "jruby" || ENV["CI"]

  describe ":mimemagic" do
    before do
      @uploader = uploader { plugin :determine_mime_type, analyzer: :mimemagic }
    end

    it "extracts content type of any IO" do
      mime_type = @uploader.send(:extract_mime_type, image)
      assert_equal "image/jpeg", mime_type
    end
  end

  describe ":mime_types" do
    before do
      @uploader = uploader { plugin :determine_mime_type, analyzer: :mime_types }
    end

    it "extract content type from the file extension" do
      mime_type = @uploader.send(:extract_mime_type, fakeio(filename: "image.png"))
      assert_equal "image/png", mime_type

      mime_type = @uploader.send(:extract_mime_type, image)
      assert_equal "image/jpeg", mime_type
    end

    it "returns nil on unkown extension" do
      mime_type = @uploader.send(:extract_mime_type, fakeio(filename: "file.foo"))
      assert_equal nil, mime_type
    end

    it "returns nil when input is not a file" do
      mime_type = @uploader.send(:extract_mime_type, fakeio)
      assert_equal nil, mime_type
    end
  end

  it "allows passing a custom extractor" do
    @uploader = uploader { plugin :determine_mime_type, analyzer: ->(io) { "foo/bar" } }
    mime_type = @uploader.send(:extract_mime_type, fakeio)
    assert_equal "foo/bar", mime_type
  end

  it "always rewinds the file" do
    @uploader = uploader { plugin :determine_mime_type, analyzer: ->(io) { io.read } }
    @uploader.send(:extract_mime_type, file = image)
    assert_equal 0, file.pos
  end
end
