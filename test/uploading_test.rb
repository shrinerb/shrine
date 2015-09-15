require "test_helper"
require "stringio"

class UploaderTest < Minitest::Test
  def setup
    @uploader = uploader(:bare)
  end

  test "interface" do
    assert_equal :store, @uploader.storage_key
    assert_equal @uploader.class.opts, @uploader.opts
  end

  test "upload returns an UploadedFile with assigned data" do
    uploaded_file = @uploader.upload(fakeio)

    assert_kind_of Uploadie::UploadedFile, uploaded_file
    assert_equal ["id", "storage", "metadata"], uploaded_file.data.keys
  end

  test "upload generates a unique location if it wasn't given" do
    uploaded_file = @uploader.upload(fakeio("image"))
    assert_equal "image", @storage.read(uploaded_file.id)

    another_uploaded_file = @uploader.upload(fakeio)
    refute_equal uploaded_file.id, another_uploaded_file.id
  end

  test "generated location preserves the extension" do
    # Rails file
    uploaded_file = @uploader.upload(fakeio(filename: "avatar.jpg"))
    assert_match /\.jpg$/, uploaded_file.id

    # Uploaded file
    second_uploaded_file = @uploader.upload(uploaded_file)
    assert_match /\.jpg$/, second_uploaded_file.id

    # File
    uploaded_file = @uploader.upload(File.open(__FILE__))
    assert_match /\.rb$/, uploaded_file.id
  end

  test "generating location handles unkown filenames" do
    uploaded_file = @uploader.upload(fakeio)

    assert_match /^[\w-]+$/, uploaded_file.id
  end

  test "uploading accepts a context" do
    @uploader.upload(fakeio("image"), type: :image)
  end

  test "upload assigns storage and extracts metadata" do
    uploaded_file = @uploader.upload(fakeio)

    assert_equal "store", uploaded_file.data["storage"]
    assert_instance_of Hash, uploaded_file.data["metadata"]
  end

  test "can tell if it uploaded an UploadedFile" do
    uploaded_file = @uploader.upload(fakeio("image"))

    assert @uploader.uploaded?(uploaded_file)
  end

  test "upload validates that the given object is an IO" do
    assert_raises(Uploadie::InvalidFile) { @uploader.upload("not an IO") }
  end
end
