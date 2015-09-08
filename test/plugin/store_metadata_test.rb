require "test_helper"
require "mini_magick"
require "rmagick"
require "dimensions"

class StoreMetadataTest < Minitest::Test
  def dimensions_uploader(library)
    uploader(:bare) { plugin :store_dimensions, library: library }
  end

  test "storing dimensions with MiniMagick" do
    @uploader = dimensions_uploader(:mini_magick)
    uploaded_file = @uploader.upload(image)

    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]
  end

  test "storing dimensions with RMagick" do
    @uploader = dimensions_uploader(:rmagick)
    uploaded_file = @uploader.upload(image)

    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]
  end

  test "storing dimensions with Dimensions" do
    @uploader = dimensions_uploader(:dimensions)

    uploaded_file = @uploader.upload(image)
    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]

    uploaded_file = @uploader.upload(StringIO.new(image.read))
    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]
  end

  test "reuploading reuses the dimensions" do
    @uploader = dimensions_uploader(:mini_magick)

    uploaded_file = @uploader.upload(image)
    reuploaded_file = @uploader.upload(uploaded_file)

    assert_equal 100, reuploaded_file.metadata["width"]
    assert_equal 67, reuploaded_file.metadata["height"]
  end

  test "UploadedFile gets `width` and `height` methods" do
    @uploader = dimensions_uploader(:mini_magick)
    uploaded_file = @uploader.upload(image)

    assert_equal uploaded_file.metadata["width"], uploaded_file.width
    assert_equal uploaded_file.metadata["height"], uploaded_file.height
  end

  test "passing unsupported library" do
    assert_raises(Uploadie::Error) { dimensions_uploader(:foo) }
  end
end
