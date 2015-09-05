require "test_helper"

class StoreFilenameTest < Minitest::Test
  def setup
    @uploader = uploader(:store_filename)
  end

  test "filename gets stored into metadata" do
    # original_filename
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"))
    assert_equal "foo.jpg", uploaded_file.metadata["original_filename"]

    # id
    second_uploaded_file = @uploader.upload(uploaded_file)
    assert_equal "foo.jpg", uploaded_file.metadata["original_filename"]

    # path
    uploaded_file = @uploader.upload(File.open("Gemfile"))
    assert_equal "Gemfile", uploaded_file.metadata["original_filename"]
  end

  test "filename doesn't get stored when it's unkown" do
    uploaded_file = @uploader.upload(fakeio)

    assert_equal nil, uploaded_file.metadata["original_filename"]
  end

  test "UploadedFile gets `original_filename` and `extension` methods" do
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"))

    assert_equal "foo.jpg", uploaded_file.original_filename
    assert_equal ".jpg",    uploaded_file.extension
  end
end
