require "test_helper"
require "stringio"

class UploadedFileTest < Minitest::Test
  def setup
    @uploader_class = uploader(:bare).class
  end

  test "every subclass gets its own copy" do
    refute_equal Uploadie::UploadedFile, @uploader_class::UploadedFile
    assert_equal @uploader_class, @uploader_class::UploadedFile.uploadie_class
  end

  test "interface" do
    @storage.upload(fakeio("image"), "key")
    uploaded_file = @uploader_class::UploadedFile.new(
      "id"       => "key",
      "storage"  => "store",
      "metadata" => {}
    )

    assert_io uploaded_file # UploadedFile has to itself be an IO

    assert_instance_of Hash, uploaded_file.data
    assert_equal "key", uploaded_file.id
    assert_equal @storage, uploaded_file.storage
    assert_equal Hash.new, uploaded_file.metadata

    assert_equal "image", uploaded_file.read
    assert_equal true, uploaded_file.eof?
    uploaded_file.rewind
    uploaded_file.close

    assert_equal "memory://key", uploaded_file.url
    assert_equal 5, uploaded_file.size
    assert_io uploaded_file.download
    uploaded_file.delete
    assert_equal false, uploaded_file.exists?
  end
end
