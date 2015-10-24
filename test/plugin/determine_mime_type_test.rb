require "test_helper"
require "stringio"

describe "the determine_mime_type plugin" do
  def uploader(analyzer)
    super() { plugin :determine_mime_type, analyzer: analyzer }
  end

  describe ":filemagic" do
    it "determines content type from file contents" do
      @uploader = uploader(:filemagic)
      uploaded_file = @uploader.upload(image)

      assert_equal "image/jpeg", uploaded_file.mime_type
    end

    it "rewinds the file after reading from it" do
      @uploader = uploader(:filemagic)
      uploaded_file = @uploader.upload(file = fakeio("nature"))

      assert_equal "nature", file.read
    end
  end unless RUBY_ENGINE == "jruby"

  describe ":file" do
    it "determines content type from file contents" do
      @uploader = uploader(:file)
      uploaded_file = @uploader.upload(image)

      assert_equal "image/jpeg", uploaded_file.mime_type
    end

    it "returns nil when IO was not a file" do
      @uploader = uploader(:file)
      stringio = StringIO.new(image.read)
      uploaded_file = @uploader.upload(stringio)

      assert_equal nil, uploaded_file.mime_type
    end
  end

  describe ":mimemagic" do
    it "extracts content type of any IO" do
      @uploader = uploader(:mimemagic)
      stringio = StringIO.new(image.read)
      uploaded_file = @uploader.upload(stringio)

      assert_equal "image/jpeg", uploaded_file.mime_type
    end
  end

  describe ":mime_types" do
    it "extract content type from the file extension" do
      @uploader = uploader(:mime_types)

      uploaded_file = @uploader.upload(fakeio(filename: "image.png"))
      assert_equal "image/png", uploaded_file.mime_type

      uploaded_file = @uploader.upload(File.open(image_path))
      assert_equal "image/jpeg", uploaded_file.mime_type
    end

    it "returns nil on unkown extension" do
      @uploader = uploader(:mime_types)
      uploaded_file = @uploader.upload(fakeio(filename: "file.foo"))

      assert_equal nil, uploaded_file.mime_type
    end

    it "returns nil when input is not a file" do
      @uploader = uploader(:mime_types)
      uploaded_file = @uploader.upload(fakeio)

      assert_equal nil, uploaded_file.mime_type
    end
  end

  it "allows passing a custom extractor" do
    @uploader = uploader ->(io) { "foo/bar" }
    uploaded_file = @uploader.upload(fakeio)

    assert_equal "foo/bar", uploaded_file.mime_type
  end

  it "doesn't do extracting on UploadedFiles" do
    @uploader = uploader(:file)
    uploaded_file = @uploader.upload(image)
    another_uploaded_file = @uploader.upload(uploaded_file)

    assert_equal "image/jpeg", another_uploaded_file.mime_type
  end
end
