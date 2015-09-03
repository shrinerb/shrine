require "test_helper"

class StoreFilesize < Minitest::Test
  def setup
    @uploader = uploader(:store_filesize)
  end

  test "filesize gets stored into metadata" do
    uploaded_file = @uploader.upload(FakeIO.new("file"))

    assert_equal 4, uploaded_file.metadata["size"]
  end

  test "UploadedFile gets `size` method" do
    uploaded_file = @uploader.upload(FakeIO.new("file"))

    assert_equal 4, uploaded_file.size
  end
end
