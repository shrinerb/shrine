require "test_helper"
require "mime/types/columnar"
require "mini_magick"
require "rmagick"
require "dimensions"

class StoreMetadataTest < Minitest::Test
  def setup
    @uploader = uploader(:store_metadata)
  end

  test "filename gets stored into metadata" do
    # original_filename
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"))
    assert_equal "foo.jpg", uploaded_file.metadata["filename"]

    # id
    second_uploaded_file = @uploader.upload(uploaded_file)
    assert_equal "foo.jpg", uploaded_file.metadata["filename"]

    # path
    uploaded_file = @uploader.upload(File.open("Gemfile"))
    assert_equal "Gemfile", uploaded_file.metadata["filename"]
  end

  test "filename doesn't get stored when it's unkown" do
    uploaded_file = @uploader.upload(fakeio)

    assert_equal nil, uploaded_file.metadata["filename"]
  end

  test "UploadedFile gets `original_filename` and `extension` methods" do
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"))

    assert_equal "foo.jpg", uploaded_file.original_filename
    assert_equal ".jpg",    uploaded_file.extension
  end

  test "filesize gets stored into metadata" do
    uploaded_file = @uploader.upload(fakeio("image"))

    assert_equal 5, uploaded_file.metadata["size"]
  end

  test "UploadedFile gets `size` method" do
    uploaded_file = @uploader.upload(fakeio("image"))

    assert_equal 5, uploaded_file.size
  end

  test "content type gets stored into metadata" do
    uploaded_file = @uploader.upload(fakeio(content_type: "image/jpeg"))

    assert_equal "image/jpeg", uploaded_file.metadata["content_type"]
  end

  test "determining content type with mime-types" do
    uploaded_file = @uploader.upload(fakeio(filename: "avatar.png"))

    assert_equal "image/png", uploaded_file.metadata["content_type"]
  end

  test "content type doesn't get stored when it's unkown" do
    uploaded_file = @uploader.upload(fakeio)
    assert_equal nil, uploaded_file.metadata["content_type"]

    uploaded_file = @uploader.upload(fakeio(filename: "avatar.foo"))
    assert_equal nil, uploaded_file.metadata["content_type"]
  end

  test "UploadedFile gets `content_type` method" do
    uploaded_file = @uploader.upload(fakeio(content_type: "image/jpeg"))

    assert_equal "image/jpeg", uploaded_file.content_type
  end

  test "storing dimensions with MiniMagick" do
    @uploader = uploader(:bare) { plugin :store_metadata, dimensions: :mini_magick }
    uploaded_file = @uploader.upload(image)

    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]
  end

  test "storing dimensions with RMagick" do
    @uploader = uploader(:bare) { plugin :store_metadata, dimensions: :rmagick }
    uploaded_file = @uploader.upload(image)

    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]
  end

  test "storing dimensions with Dimensions" do
    @uploader = uploader(:bare) { plugin :store_metadata, dimensions: :dimensions }

    uploaded_file = @uploader.upload(image)
    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]

    uploaded_file = @uploader.upload(StringIO.new(image.read))
    assert_equal 100, uploaded_file.metadata["width"]
    assert_equal 67, uploaded_file.metadata["height"]
  end

  test "reuploading reuses the dimensions" do
    @uploader = uploader(:bare) { plugin :store_metadata, dimensions: :mini_magick }

    uploaded_file = @uploader.upload(image)
    reuploaded_file = @uploader.upload(uploaded_file)

    assert_equal 100, reuploaded_file.metadata["width"]
    assert_equal 67, reuploaded_file.metadata["height"]
  end

  test "UploadedFile gets `width` and `height` methods" do
    @uploader = uploader(:bare) { plugin :store_metadata, dimensions: :dimensions }
    uploaded_file = @uploader.upload(image)

    assert_equal uploaded_file.metadata["width"], uploaded_file.width
    assert_equal uploaded_file.metadata["height"], uploaded_file.height
  end

  test "passing unsupported or no dimension library" do
    assert_raises(Uploadie::Error) do
      uploader(:bare) { plugin :store_metadata, dimensions: true }
    end

    assert_raises(Uploadie::Error) do
      @uploader = uploader(:bare) { plugin :store_metadata, dimensions: :foo }
      @uploader.upload(image)
    end
  end
end
