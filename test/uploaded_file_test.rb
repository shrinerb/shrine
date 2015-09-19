require "test_helper"
require "set"

class UploadedFileTest < Minitest::Test
  def setup
    @uploader = uploader(:store)
  end

  test "every subclass gets its own copy" do
    refute_equal Shrine::UploadedFile, @uploader.class::UploadedFile
    assert_equal @uploader.class, @uploader.class::UploadedFile.shrine_class
  end

  test "main interface" do
    uploaded_file = @uploader.upload(fakeio("image"), location: "key")

    assert_instance_of Hash, uploaded_file.data
    assert_equal "key", uploaded_file.id
    assert_equal "store", uploaded_file.storage_key
    assert_instance_of Hash, uploaded_file.metadata

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
    io = fakeio("image", filename: "foo.jpg", content_type: "image/jpeg")
    uploaded_file = @uploader.upload(io)

    assert_equal "foo.jpg", uploaded_file.original_filename
    assert_equal 5, uploaded_file.size
    assert_equal "image/jpeg", uploaded_file.content_type
  end

  test "forwards url arguments to storage" do
    @uploader.storage.singleton_class.class_eval do
      def url(id, **options)
        options
      end
    end
    uploaded_file = @uploader.upload(fakeio)

    assert_equal Hash[foo: "foo"], uploaded_file.url(foo: "foo")
  end

  test "JSON" do
    uploaded_file = @uploader.class::UploadedFile.new(
      "id"       => "123",
      "storage"  => "store",
      "metadata" => {},
    )

    assert_equal '{"id":"123","storage":"store","metadata":{}}', uploaded_file.to_json
    assert_equal '{"thumb":{"id":"123","storage":"store","metadata":{}}}', {thumb: uploaded_file}.to_json
  end

  test "equality" do
    assert_equal(
      @uploader.class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {}),
      @uploader.class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {}),
    )

    refute_equal(
      @uploader.class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {}),
      @uploader.class::UploadedFile.new("id" => "foo", "storage" => "cache", "metadata" => {}),
    )

    refute_equal(
      @uploader.class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {}),
      @uploader.class::UploadedFile.new("id" => "bar", "storage" => "store", "metadata" => {}),
    )
  end

  test "hash equality" do
    uploaded_file1 = @uploader.class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {})
    uploaded_file2 = @uploader.class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {})

    assert_equal 1, Set.new([uploaded_file1, uploaded_file2]).count
  end
end
