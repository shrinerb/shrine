require "test_helper"
require "minitest/mock"

class InstanceTest < Minitest::Test
  def setup
    @uploader = uploader(:store)
  end

  test "interface" do
    assert_equal :store, @uploader.storage_key
    assert_equal @uploader.class.opts, @uploader.opts
  end

  test "upload returns an UploadedFile with assigned data" do
    uploaded_file = @uploader.upload(fakeio)

    assert_kind_of Shrine::UploadedFile, uploaded_file
    assert_equal ["id", "storage", "metadata"], uploaded_file.data.keys
  end

  test "uploading accepts a context" do
    @uploader.upload(fakeio("image"), type: :image)
  end

  test "upload assigns storage and extracts metadata" do
    uploaded_file = @uploader.upload(fakeio)

    assert_equal "store", uploaded_file.data["storage"]
    assert_instance_of Hash, uploaded_file.data["metadata"]
  end

  test "upload calls #process" do
    @uploader.stub(:process, fakeio("processed")) do
      uploaded_file = @uploader.upload(fakeio)
      assert_equal "processed", uploaded_file.read
    end
  end

  test "#delete deletes the file" do
    uploaded_file = @uploader.upload(fakeio)
    @uploader.delete(uploaded_file)

    refute uploaded_file.exists?
  end

  test "#delete returns the deleted files" do
    uploaded_file = @uploader.upload(fakeio)
    result = @uploader.delete(uploaded_file)

    assert_equal uploaded_file, result
  end

  test "checking IO-ness of file happens after processing" do
    @uploader.stub(:process, "invalid file") do
      assert_raises(Shrine::InvalidFile) { @uploader.upload(fakeio) }
    end
  end

  test "can tell if it uploaded an UploadedFile" do
    uploaded_file = @uploader.upload(fakeio("image"))

    assert @uploader.uploaded?(uploaded_file)
  end

  test "upload validates that the given object is an IO" do
    assert_raises(Shrine::InvalidFile) { @uploader.upload("not an IO") }
  end
end
