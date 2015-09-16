require "test_helper"

class MetadataTest < Minitest::Test
  def setup
    @uploader = uploader
  end

  test "filename gets stored into metadata" do
    # original_filename
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"))
    assert_equal "foo.jpg", uploaded_file.metadata["filename"]

    # path
    uploaded_file = @uploader.upload(File.open("Gemfile"))
    assert_equal "Gemfile", uploaded_file.metadata["filename"]
  end

  test "filename doesn't get stored when it's unkown" do
    uploaded_file = @uploader.upload(fakeio)

    assert_equal nil, uploaded_file.metadata.fetch("filename")
  end

  test "filesize gets stored into metadata" do
    uploaded_file = @uploader.upload(fakeio("image"))

    assert_equal 5, uploaded_file.metadata["size"]
  end

  test "content type gets stored into metadata" do
    uploaded_file = @uploader.upload(fakeio(content_type: "image/jpeg"))

    assert_equal "image/jpeg", uploaded_file.metadata["content_type"]
  end

  test "content type doesn't get stored when it's unkown" do
    uploaded_file = @uploader.upload(fakeio)
    assert_equal nil, uploaded_file.metadata.fetch("content_type")
  end

  test "metadata gets transfered from one UploadedFile to another" do
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg", content_type: "image/jpeg"))
    reuploaded_file = @uploader.upload(uploaded_file)

    assert_equal "foo.jpg", reuploaded_file.original_filename
    assert_equal "image/jpeg", reuploaded_file.content_type
    assert_equal uploaded_file.size, reuploaded_file.size
  end
end
