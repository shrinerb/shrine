require "test_helper"

class StoreDimensionsTest < Minitest::Test
  def uploader(extractor)
    super() { plugin :store_dimensions, extractor: extractor }
  end

  test "storing dimensions with FastImage" do
    @uploader = uploader(:fastimage)

    uploaded_file = @uploader.upload(image)
    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]

    @uploader = uploader(:fastimage)

    uploaded_file = @uploader.upload(FakeIO.new(image.read))
    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]
  end

  test "storing dimensions with custom extractor" do
    @uploader = uploader ->(io) {[5, 10]}
    uploaded_file = @uploader.upload(image)

    assert_equal 5, uploaded_file.metadata["width"]
    assert_equal 10, uploaded_file.metadata["height"]
  end

  test "reuploading reuses the dimensions" do
    @uploader = uploader(:fastimage)

    uploaded_file = @uploader.upload(image)
    reuploaded_file = @uploader.upload(uploaded_file)

    assert_equal 100, reuploaded_file.metadata["width"]
    assert_equal 67, reuploaded_file.metadata["height"]
  end

  test "UploadedFile gets `width` and `height` methods" do
    @uploader = uploader(:fastimage)
    uploaded_file = @uploader.upload(image)

    assert_equal uploaded_file.metadata["width"], uploaded_file.width
    assert_equal uploaded_file.metadata["height"], uploaded_file.height
  end
end
