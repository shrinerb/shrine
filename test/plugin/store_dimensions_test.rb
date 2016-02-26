require "test_helper"

describe "the store_dimensions plugin" do
  def uploader(analyzer)
    super() { plugin :store_dimensions, analyzer: analyzer }
  end

  describe ":fastimage" do
    it "extracts dimensions from files" do
      @uploader = uploader(:fastimage)

      uploaded_file = @uploader.upload(image)
      assert_equal 100, uploaded_file.metadata["width"]
      assert_equal 67, uploaded_file.metadata["height"]
    end

    it "extracts dimensions from non-files" do
      @uploader = uploader(:fastimage)

      uploaded_file = @uploader.upload(FakeIO.new(image.read))
      assert_equal 100, uploaded_file.metadata["width"]
      assert_equal 67, uploaded_file.metadata["height"]
    end

    it "resets cursor after reading attempting to extract dimensions from an invalid image file" do
      io = File.open("test/fixtures/invalid_image.jpg")
      @uploader = uploader(:fastimage)
      uploaded_file = @uploader.extract_dimensions(io)
      assert_equal 0, io.pos
    end
  end

  it "allows storing with custom extractor" do
    @uploader = uploader ->(io) {[5, 10]}
    uploaded_file = @uploader.upload(image)

    assert_equal 5, uploaded_file.metadata["width"]
    assert_equal 10, uploaded_file.metadata["height"]
  end

  it "persists between UploadedFiles" do
    @uploader = uploader(:fastimage)

    uploaded_file = @uploader.upload(image)
    reuploaded_file = @uploader.upload(uploaded_file)

    assert_equal 100, reuploaded_file.metadata["width"]
    assert_equal 67, reuploaded_file.metadata["height"]
  end

  it "gives UploadedFile `width` and `height` methods" do
    @uploader = uploader(:fastimage)
    uploaded_file = @uploader.upload(image)

    assert_equal uploaded_file.metadata["width"], uploaded_file.width
    assert_equal uploaded_file.metadata["height"], uploaded_file.height
  end

  it "coerces the dimensions to integer" do
    @uploader = uploader(:fastimage)
    uploaded_file = @uploader.upload(image)
    uploaded_file.metadata["width"] = "48"
    uploaded_file.metadata["height"] = "52"

    assert_equal 48, uploaded_file.width
    assert_equal 52, uploaded_file.height
  end

  it "allows dimensions to be missing or nil" do
    @uploader = uploader(:fastimage)
    uploaded_file = @uploader.upload(image)
    uploaded_file.metadata["width"] = nil
    uploaded_file.metadata.delete("height")

    assert_equal nil, uploaded_file.width
    assert_equal nil, uploaded_file.height
  end
end
