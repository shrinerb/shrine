require "test_helper"
require "shrine/storage/file_system"
require "set"
require "mocha/mini_test"

describe Shrine::UploadedFile do
  before do
    @uploader = uploader
  end

  it "is an IO" do
    Shrine.io! @uploader.upload(fakeio)
  end

  it "exposes data readers" do
    uploaded_file = @uploader.upload(fakeio, location: "key")

    assert_instance_of Hash, uploaded_file.data
    assert_equal "key", uploaded_file.id
    assert_equal "store", uploaded_file.storage_key
    assert_instance_of Hash, uploaded_file.metadata
  end

  it "has metadata readers" do
    io = fakeio("image", filename: "foo.jpg", content_type: "image/jpeg")
    uploaded_file = @uploader.upload(io)

    assert_equal "foo.jpg", uploaded_file.original_filename
    assert_equal 5, uploaded_file.size
    assert_equal "image/jpeg", uploaded_file.mime_type
  end

  it "exposes the extension" do
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"))
    assert_equal "jpg", uploaded_file.extension

    uploaded_file = @uploader.upload(fakeio(filename: "foo"))
    assert_equal nil, uploaded_file.extension

    uploaded_file = @uploader.upload(fakeio)
    assert_equal nil, uploaded_file.extension
  end

  it "coerces the size to integer" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.metadata["size"] = "13"

    assert_equal 13, uploaded_file.size
  end

  it "has IO-related methods" do
    uploaded_file = @uploader.upload(fakeio("image"), location: "key")

    Shrine.io!(uploaded_file.to_io)

    assert_equal "image", uploaded_file.read
    assert_equal true, uploaded_file.eof?
    uploaded_file.rewind
    uploaded_file.close
  end

  it "has storage related methods" do
    uploaded_file = @uploader.upload(fakeio("image"), location: "key")

    assert_equal "memory://key", uploaded_file.url
    assert_instance_of Tempfile, uploaded_file.download
    uploaded_file.delete
    assert_equal false, uploaded_file.exists?

    assert_instance_of Shrine::Storage::Memory, uploaded_file.storage
    assert_instance_of @uploader.class, uploaded_file.uploader
  end

  it "doesn't attempt to delete itself twice" do
    uploaded_file = @uploader.upload(fakeio("image"))
    uploaded_file.storage.expects(:delete).once

    uploaded_file.delete
    uploaded_file.delete
  end

  it "can be replaced with another file" do
    uploaded_file = @uploader.upload(fakeio("image"), location: "key")

    replaced = uploaded_file.replace(fakeio("replaced"))

    assert_equal 8, replaced.size
    assert_equal "replaced", replaced.read
  end

  it "forwards url arguments to storage" do
    @uploader.storage.instance_eval do
      def url(id, **options)
        options.to_json
      end
    end
    uploaded_file = @uploader.upload(fakeio)

    assert_equal '{"foo":"bar"}', uploaded_file.url(foo: "bar")
  end

  it "implements #to_json" do
    uploaded_file = @uploader.class::UploadedFile.new(
      "id"       => "123",
      "storage"  => "store",
      "metadata" => {},
    )

    assert_equal '{"id":"123","storage":"store","metadata":{}}',
                  uploaded_file.to_json

    assert_equal '{"thumb":{"id":"123","storage":"store","metadata":{}}}',
                  {thumb: uploaded_file}.to_json
  end

  it "implements equality" do
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

  it "implements hash equality" do
    uploaded_file1 = @uploader.class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {})
    uploaded_file2 = @uploader.class::UploadedFile.new("id" => "foo", "storage" => "store", "metadata" => {})

    assert_equal 1, Set.new([uploaded_file1, uploaded_file2]).count
  end

  it "implements cleaner #inspect" do
    uploaded_file = @uploader.class::UploadedFile.new(
      "id" => "123", "storage" => "store", "metadata" => {})

    p uploaded_file
    assert_match /#<\S+ @data=\{"id"=>"123", "storage"=>"store", "metadata"=>{}\}>/, uploaded_file.inspect
  end

  it "raises an error if invalid storage key is given" do
    assert_raises(Shrine::Error) do
      Shrine::UploadedFile.new("id" => "123", "storage" => "foo", "metadata" => {})
    end
  end
end
