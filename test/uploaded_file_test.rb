require "test_helper"
require "shrine/storage/file_system"
require "set"

describe Shrine::UploadedFile do
  before do
    @uploader = uploader(:store)
  end

  def uploaded_file(data = {})
    data = {"id" => "foo", "storage" => "store", "metadata" => {}}.merge(data)
    @uploader.class::UploadedFile.new(data)
  end

  it "is an IO" do
    assert io?(@uploader.upload(fakeio))
  end

  describe "#initialize" do
    it "assigns the data hash" do
      data = {"id" => "foo", "storage" => "store", "metadata" => {"foo" => "bar"}}
      uploaded_file = uploaded_file(data)
      assert_equal data, uploaded_file.data
    end

    it "initializes metadata if absent" do
      uploaded_file = uploaded_file("metadata" => nil)
      assert_equal Hash.new, uploaded_file.metadata
    end

    it "raises an error if storage is not registered" do
      data = {"id" => "foo", "storage" => "foo"}
      assert_raises(Shrine::Error) { uploaded_file(data) }
    end

    it "doesn't create symbols for unregistered storage names" do
      data = {"id" => "foo", "storage" => "nosymbol"}
      assert_raises(Shrine::Error) { uploaded_file(data) }
      refute_includes Symbol.all_symbols.map(&:to_s), "nosymbol"
    end
  end

  describe "#id" do
    it "is fetched from data" do
      uploaded_file = uploaded_file("id" => "foo")
      assert_equal "foo", uploaded_file.id
      uploaded_file.data["id"] = "bar"
      assert_equal "bar", uploaded_file.id
    end
  end

  describe "#storage_key" do
    it "is fetched from data" do
      uploaded_file = uploaded_file("storage" => "store")
      assert_equal "store", uploaded_file.storage_key
      uploaded_file.data["storage"] = "cache"
      assert_equal "cache", uploaded_file.storage_key
    end
  end

  describe "#metadata" do
    it "is fetched from data" do
      uploaded_file = uploaded_file("metadata" => {"foo" => "foo"})
      assert_equal Hash["foo" => "foo"], uploaded_file.metadata
      uploaded_file.data["metadata"] = {"bar" => "bar"}
      assert_equal Hash["bar" => "bar"], uploaded_file.metadata
      uploaded_file.data["metadata"].replace({"baz" => "baz"})
      assert_equal Hash["baz" => "baz"], uploaded_file.metadata
    end
  end

  describe "#original_filename" do
    it "returns filename from metadata" do
      uploaded_file = uploaded_file("metadata" => {"filename" => "foo.jpg"})
      assert_equal "foo.jpg", uploaded_file.original_filename

      uploaded_file = uploaded_file("metadata" => {"filename" => nil})
      assert_equal nil, uploaded_file.original_filename

      uploaded_file = uploaded_file("metadata" => {})
      assert_equal nil, uploaded_file.original_filename
    end
  end

  describe "#extension" do
    it "extracts file extension from id" do
      uploaded_file = uploaded_file("id" => "foo.jpg")
      assert_equal "jpg", uploaded_file.extension

      uploaded_file = uploaded_file("id" => "foo")
      assert_equal nil, uploaded_file.extension
    end

    it "extracts file extension from filename" do
      uploaded_file = uploaded_file("metadata" => {"filename" => "foo.jpg"})
      assert_equal "jpg", uploaded_file.extension

      uploaded_file = uploaded_file("metadata" => {"filename" => "foo"})
      assert_equal nil, uploaded_file.extension

      uploaded_file = uploaded_file("metadata" => {})
      assert_equal nil, uploaded_file.extension
    end

    # Some storages may reformat the file on upload, changing its extension,
    # so we want to make sure that we take the new extension, and not the
    # extension file had before upload.
    it "prefers extension from id over one from filename" do
      uploaded_file = uploaded_file("id" => "foo.jpg", "metadata" => {"filename" => "foo.png"})
      assert_equal "jpg", uploaded_file.extension
    end
  end

  describe "#size" do
    it "returns size from metadata" do
      uploaded_file = uploaded_file("metadata" => {"size" => 50})
      assert_equal 50, uploaded_file.size

      uploaded_file = uploaded_file("metadata" => {"size" => nil})
      assert_equal nil, uploaded_file.size

      uploaded_file = uploaded_file("metadata" => {})
      assert_equal nil, uploaded_file.size
    end

    it "converts the value to integer" do
      uploaded_file = uploaded_file("metadata" => {"size" => "50"})
      assert_equal 50, uploaded_file.size

      uploaded_file = uploaded_file("metadata" => {"size" => "not a number"})
      assert_raises(ArgumentError) { uploaded_file.size }
    end
  end

  describe "#mime_type" do
    it "returns mime_type from metadata" do
      uploaded_file = uploaded_file("metadata" => {"mime_type" => "image/jpeg"})
      assert_equal "image/jpeg", uploaded_file.mime_type

      uploaded_file = uploaded_file("metadata" => {"mime_type" => nil})
      assert_equal nil, uploaded_file.mime_type

      uploaded_file = uploaded_file("metadata" => {})
      assert_equal nil, uploaded_file.mime_type
    end

    it "has #content_type alias" do
      uploaded_file = uploaded_file("metadata" => {"mime_type" => "image/jpeg"})
      assert_equal "image/jpeg", uploaded_file.content_type
    end
  end

  describe "#read" do
    it "delegates to underlying IO" do
      uploaded_file = @uploader.upload(fakeio("file"))
      assert_equal "file", uploaded_file.read
      uploaded_file.rewind
      assert_equal "fi", uploaded_file.read(2)
      assert_equal "le", uploaded_file.read(2)
      assert_equal nil,  uploaded_file.read(2)
    end
  end

  describe "#eof?" do
    it "delegates to underlying IO" do
      uploaded_file = @uploader.upload(fakeio("file"))
      refute uploaded_file.eof?
      uploaded_file.read
      assert uploaded_file.eof?
    end
  end

  describe "#close" do
    it "delegates to underlying IO" do
      uploaded_file = @uploader.upload(fakeio("file"))
      uploaded_file.read
      uploaded_file.close
      assert_raises(IOError) { uploaded_file.read }
    end

    it "deletes the underlying tempfile" do
      uploaded_file = @uploader.upload(fakeio)
      uploaded_file.instance_variable_set("@io", tempfile = Tempfile.new(""))
      uploaded_file.close
      refute tempfile.path
    end

    # Sometimes an uploaded file will be copied over instead of reuploaded (S3),
    # in which case it's not downloaded, so we don't want that closing actually
    # downloads the file.
    it "doesn't open the file if it wasn't opened yet" do
      uploaded_file = @uploader.upload(fakeio)
      uploaded_file.storage.expects(:open).never
      uploaded_file.close
    end
  end

  describe "#rewind" do
    it "delegates to underlying IO" do
      uploaded_file = @uploader.upload(fakeio("file"))
      assert_equal "file", uploaded_file.read
      uploaded_file.rewind
      assert_equal "file", uploaded_file.read
    end
  end

  describe "#url" do
    it "delegates to underlying storage" do
      uploaded_file = uploaded_file("id" => "foo")
      assert_equal "memory://foo", uploaded_file.url
    end

    it "forwards given options to storage" do
      uploaded_file = uploaded_file("id" => "foo")
      uploaded_file.storage.expects(:url).with("foo", {foo: "foo"})
      uploaded_file.url(foo: "foo")
    end
  end

  describe "#exists?" do
    it "delegates to underlying storage" do
      uploaded_file = @uploader.upload(fakeio)
      assert uploaded_file.exists?

      uploaded_file = uploaded_file({})
      refute uploaded_file.exists?
    end
  end

  describe "#download" do
    it "delegates to underlying storage" do
      uploaded_file = @uploader.upload(fakeio)
      assert_instance_of Tempfile, uploaded_file.download
    end
  end

  describe "#replace" do
    it "uploads another file to the same location" do
      uploaded_file = @uploader.upload(fakeio("file"))
      new_uploaded_file = uploaded_file.replace(fakeio("replaced"))

      assert_equal uploaded_file.id, new_uploaded_file.id
      assert_equal "replaced", new_uploaded_file.read
      assert_equal 8, new_uploaded_file.size
    end
  end

  describe "#delete" do
    it "delegates to underlying storage" do
      uploaded_file = @uploader.upload(fakeio)
      uploaded_file.delete
      refute uploaded_file.exists?
    end
  end

  describe "#to_io" do
    it "returns the underlying IO" do
      uploaded_file = @uploader.upload(fakeio)
      assert io?(uploaded_file.to_io)
      assert_equal uploaded_file.object_id, uploaded_file.object_id
    end
  end

  it "exposes #storage and #uploader" do
    uploaded_file = uploaded_file({})
    assert_instance_of Shrine::Storage::Memory, uploaded_file.storage
    assert_instance_of uploaded_file.shrine_class, uploaded_file.uploader
  end

  it "implements #to_json" do
    uploaded_file = uploaded_file("id" => "foo", "storage" => "store", "metadata" => {})
    assert_equal '{"id":"foo","storage":"store","metadata":{}}', uploaded_file.to_json
    assert_equal '{"thumb":{"id":"foo","storage":"store","metadata":{}}}', {thumb: uploaded_file}.to_json
  end

  it "implements equality" do
    assert_equal uploaded_file(), uploaded_file()
    assert_equal uploaded_file("metadata" => {"foo" => "foo"}), uploaded_file("metadata" => {"bar" => "bar"})
    refute_equal uploaded_file("id" => "foo"), uploaded_file("id" => "bar")
    refute_equal uploaded_file("storage" => "store"), uploaded_file("storage" => "cache")
  end

  it "implements hash equality" do
    assert_equal 1, Set.new([uploaded_file(), uploaded_file()]).size
    assert_equal 2, Set.new([uploaded_file("id" => "foo"), uploaded_file("id" => "bar")]).size
    assert_equal 2, Set.new([uploaded_file("storage" => "store"), uploaded_file("storage" => "cache")]).size
  end

  it "implements cleaner #inspect" do
    uploaded_file = uploaded_file("id" => "123", "storage" => "store", "metadata" => {})
    assert_match /#<\S+ @data=\{"id"=>"123", "storage"=>"store", "metadata"=>{}\}>/, uploaded_file.inspect
  end
end
