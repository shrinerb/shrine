require "test_helper"
require "stringio"

describe "determine_mime_type plugin" do
  def uploader(analyser)
    super() { plugin :determine_mime_type, analyser: analyser }
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
  end

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
