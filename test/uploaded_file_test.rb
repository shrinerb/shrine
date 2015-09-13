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

  test "main interface" do
    @storage.upload(fakeio("image"), "key")
    uploaded_file = @uploader_class::UploadedFile.new(
      "id"       => "key",
      "storage"  => "store",
      "metadata" => {}
    )

    assert_instance_of Hash, uploaded_file.data
    assert_equal "key", uploaded_file.id
    assert_equal :store, uploaded_file.storage_key
    assert_equal Hash.new, uploaded_file.metadata

    assert_equal "image", uploaded_file.read
    assert_equal true, uploaded_file.eof?
    uploaded_file.rewind
    uploaded_file.close

    assert_equal "memory://key", uploaded_file.url
    assert_instance_of Tempfile, uploaded_file.download
    uploaded_file.delete
    assert_equal false, uploaded_file.exists?
  end

  test "metadata interface" do
    uploaded_file = @uploader_class::UploadedFile.new(
      "id"       => "123",
      "storage"  => "store",
      "metadata" => {"filename" => "foo.jpg", "size" => 5, "content_type" => "image/jpeg"}
    )

    assert_equal "foo.jpg", uploaded_file.original_filename
    assert_equal 5, uploaded_file.size
    assert_equal "image/jpeg", uploaded_file.content_type
  end

  test "equality" do
    assert_equal(
      @uploader_class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {}),
      @uploader_class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {}),
    )

    refute_equal(
      @uploader_class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {}),
      @uploader_class::UploadedFile.new("id" => "foo", "storage" => "cache", "metadata" => {}),
    )

    refute_equal(
      @uploader_class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {}),
      @uploader_class::UploadedFile.new("id" => "bar", "storage" => "store", "metadata" => {}),
    )
  end
end
