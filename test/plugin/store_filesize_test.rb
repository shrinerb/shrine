require "test_helper"

class StoreFilesize < Minitest::Test
  def setup
    @uploader = uploader(:store_filesize)
  end

  test "filesize gets stored into metadata" do
    uploaded_file = @uploader.upload(fakeio("image"))

    assert_equal 5, uploaded_file.metadata["size"]
  end

  test "UploadedFile gets `size` method" do
    uploaded_file = @uploader.upload(fakeio("image"))

    assert_equal 5, uploaded_file.size
  end
end
