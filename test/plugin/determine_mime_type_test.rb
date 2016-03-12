require "test_helper"
require "stringio"

describe "the determine_mime_type plugin" do
  describe ":file" do
    before do
      @uploader = uploader do
        plugin :determine_mime_type, analyzer: :file
      end
    end

    it "determines content type from file contents" do
      uploaded_file = @uploader.upload(image)
      assert_equal "image/jpeg", uploaded_file.mime_type
    end

    it "is able to determine content type for non-files" do
      uploaded_file = @uploader.upload(fakeio(image.read))
      assert_equal "image/jpeg", uploaded_file.mime_type
      assert_equal image.read, uploaded_file.read
    end
  end

  describe ":filemagic" do
    before do
      @uploader = uploader do
        plugin :determine_mime_type, analyzer: :filemagic
      end
    end

    it "determines content type from file contents" do
      uploaded_file = @uploader.upload(image)
      assert_equal "image/jpeg", uploaded_file.mime_type
      assert_equal image.read, uploaded_file.read
    end
  end unless RUBY_ENGINE == "jruby" || ENV["CI"]

  describe ":mimemagic" do
    before do
      @uploader = uploader do
        plugin :determine_mime_type, analyzer: :mimemagic
      end
    end

    it "extracts content type of any IO" do
      uploaded_file = @uploader.upload(fakeio(image.read))
      assert_equal "image/jpeg", uploaded_file.mime_type
      assert_equal image.read, uploaded_file.read
    end
  end

  describe ":mime_types" do
    before do
      @uploader = uploader do
        plugin :determine_mime_type, analyzer: :mime_types
      end
    end

    it "extract content type from the file extension" do
      uploaded_file = @uploader.upload(fakeio(filename: "image.png"))
      assert_equal "image/png", uploaded_file.mime_type

      uploaded_file = @uploader.upload(image)
      assert_equal "image/jpeg", uploaded_file.mime_type
    end

    it "returns nil on unkown extension" do
      uploaded_file = @uploader.upload(fakeio(filename: "file.foo"))
      assert_equal nil, uploaded_file.mime_type
    end

    it "returns nil when input is not a file" do
      uploaded_file = @uploader.upload(fakeio)
      assert_equal nil, uploaded_file.mime_type
    end
  end

  it "allows passing a custom extractor" do
    @uploader = uploader do
      plugin :determine_mime_type, analyzer: ->(io) { "foo/bar" }
    end

    uploaded_file = @uploader.upload(fakeio)
    assert_equal "foo/bar", uploaded_file.mime_type
  end

  it "extracts MIME type from UploadedFiles" do
    @uploader = uploader do
      plugin :determine_mime_type, analyzer: :mime_types
    end

    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"))
    mime_type = @uploader.extract_mime_type(uploaded_file)
    assert_equal "image/jpeg", mime_type
  end
end
