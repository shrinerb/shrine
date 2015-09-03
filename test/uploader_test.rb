require "test_helper"
require "stringio"

class UploaderTest < Minitest::Test
  def setup
    @uploader = uploader(:bare)
  end

  test "interface" do
    assert_equal :memory, @uploader.storage_key
    assert_equal @storage, @uploader.storage
    assert_equal @uploader.class.opts, @uploader.opts
  end

  test "upload returns an UploadedFile with assigned data" do
    uploaded_file = @uploader.upload(FakeIO.new("file"))

    assert_kind_of Uploadie::UploadedFile, uploaded_file
    assert_equal ["id", "storage", "metadata"], uploaded_file.data.keys
  end

  test "upload generates a unique location if it wasn't given" do
    uploaded_file = @uploader.upload(FakeIO.new("file"))
    assert_equal "file", @storage.read(uploaded_file.id)

    another_uploaded_file = @uploader.upload(FakeIO.new("file"))
    refute_equal uploaded_file.id, another_uploaded_file.id
  end

  test "generated location preserves the extension" do
    # original_filename
    uploaded_file = @uploader.upload(FakeIO.new("file", filename: "avatar.jpg"))
    assert_match /\.jpg$/, uploaded_file.id

    # path
    second_uploaded_file = @uploader.upload(uploaded_file)
    assert_match /\.jpg$/, second_uploaded_file.id

    # id
    uploaded_file = @uploader.upload(File.open(__FILE__))
    assert_match /\.rb$/, uploaded_file.id
  end

  test "generating location handles unkown filenames" do
    uploaded_file = @uploader.upload(FakeIO.new("file"))

    assert_match /^[\w-]+$/, uploaded_file.id
  end

  test "upload accepts a specific location" do
    uploaded_file = @uploader.upload(FakeIO.new("file"), "custom")

    assert_equal "custom", uploaded_file.id
    assert_equal "file", @storage.read("custom")
  end

  test "upload assigns storage and initializes metadata" do
    uploaded_file = @uploader.upload(FakeIO.new("file"), "custom")

    assert_equal "memory", uploaded_file.data["storage"]
    assert_equal @storage, uploaded_file.storage

    assert_equal Hash.new, uploaded_file.data["metadata"]
    assert_equal Hash.new, uploaded_file.metadata
  end

  test "upload validates that the given object is an IO" do
    assert_raises(Uploadie::Error, /does not respond to/) do
      @uploader.upload("not an IO")
    end
  end
end
