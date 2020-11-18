require "test_helper"

describe Shrine do
  before do
    @uploader = uploader
    @shrine   = @uploader.class
  end

  describe ".inherited" do
    it "duplicates options" do
      uploader = Class.new(Shrine)
      uploader.opts[:foo] = "foo"

      subclass = Class.new(uploader)
      assert_equal "foo", subclass.opts[:foo]

      subclass.opts[:foo] = "bar"
      assert_equal "bar", subclass.opts[:foo]
      assert_equal "foo", uploader.opts[:foo]
    end

    it "duplicates collection values of options" do
      uploader = Class.new(Shrine)
      uploader.opts[:a] = ["a"]
      uploader.opts[:b] = {"b" => "b"}
      uploader.opts[:c] = ["c"].freeze

      subclass = Class.new(uploader)

      subclass.opts[:a] << "a"
      assert_equal ["a", "a"], subclass.opts[:a]
      assert_equal ["a"],      uploader.opts[:a]

      subclass.opts[:b].update("b" => nil)
      assert_equal({"b" => nil}, subclass.opts[:b])
      assert_equal({"b" => "b"}, uploader.opts[:b])

      assert_equal ["c"], subclass.opts[:c]
    end

    it "duplicates storages" do
      uploader = Class.new(Shrine)
      uploader.storages[:foo] = "foo"

      subclass = Class.new(uploader)
      assert_equal "foo", subclass.storages[:foo]

      subclass.storages[:foo] = "bar"
      assert_equal "bar", subclass.storages[:foo]
      assert_equal "foo", uploader.storages[:foo]
    end

    it "duplicates core classes" do
      uploader = Class.new(Shrine)

      refute_equal Shrine::UploadedFile, uploader::UploadedFile
      assert_equal uploader, uploader::UploadedFile.shrine_class

      refute_equal Shrine::Attachment, uploader::Attachment
      assert_equal uploader, uploader::Attachment.shrine_class

      refute_equal Shrine::Attacher, uploader::Attacher
      assert_equal uploader, uploader::Attacher.shrine_class
    end
  end

  describe ".Attachment" do
    it "returns an instance of Attachment" do
      uploader = Class.new(Shrine)

      assert_instance_of uploader::Attachment, uploader::Attachment(:file)
      assert_instance_of uploader::Attachment, uploader.attachment(:file)
      assert_instance_of uploader::Attachment, uploader[:file]
    end
  end

  describe ".upload" do
    it "uploads the file" do
      file = @shrine.upload(fakeio, :store)

      assert_instance_of @shrine::UploadedFile, file
    end

    it "forwads additional options" do
      file = @shrine.upload(fakeio, :store, location: "foo")

      assert_equal "foo", file.id
    end
  end

  describe ".uploaded_file" do
    it "accepts data as stringified Hash" do
      uploaded_file = @uploader.upload(fakeio)
      retrieved     = @shrine.uploaded_file(uploaded_file.data)

      assert_equal uploaded_file, retrieved
    end

    it "accepts data as symbolized Hash" do
      uploaded_file = @uploader.upload(fakeio)

      data            = uploaded_file.data.transform_keys(&:to_sym)
      data[:metadata] = data[:metadata].transform_keys(&:to_sym)

      retrieved = @shrine.uploaded_file(data)

      assert_equal uploaded_file,          retrieved
      assert_equal uploaded_file.metadata, retrieved.metadata
    end

    it "accepts data as JSON" do
      uploaded_file = @uploader.upload(fakeio)
      retrieved     = @shrine.uploaded_file(uploaded_file.to_json)

      assert_equal uploaded_file, retrieved
    end

    it "accepts an UploadedFile" do
      uploaded_file = @uploader.upload(fakeio)
      retrieved     = @shrine.uploaded_file(uploaded_file)

      assert_equal uploaded_file, retrieved
    end

    it "raises an error on invalid input" do
      assert_raises(ArgumentError) { @shrine.uploaded_file(:foo) }
    end
  end

  describe ".find_storage" do
    it "finds by symbol names" do
      assert_equal @uploader.storage, @shrine.find_storage(:store)
      @shrine.storages["store"] = @shrine.storages.delete(:store)
      assert_equal @uploader.storage, @shrine.find_storage(:store)
    end

    it "finds by string names" do
      assert_equal @uploader.storage, @shrine.find_storage("store")
      @shrine.storages["store"] = @shrine.storages.delete(:store)
      assert_equal @uploader.storage, @shrine.find_storage("store")
    end

    it "raises an error if storage wasn't found" do
      assert_raises(Shrine::Error) { @shrine.find_storage(:foo) }
    end
  end

  describe ".with_file" do
    it "yields File objects unchanged" do
      file = File.open(__FILE__)
      @shrine.with_file(file) do |object|
        assert_equal file, object
      end
    end

    it "yields Tempfile objects unchanged" do
      tempfile = Tempfile.new
      @shrine.with_file(tempfile) do |object|
        assert_equal tempfile, object
      end
    end

    it "temporarily downloads Shrine::UploadedFile objects" do
      uploaded_file = @uploader.upload(fakeio, location: "file.txt")
      tempfile = @shrine.with_file(uploaded_file) do |tempfile|
        assert_instance_of Tempfile, tempfile
        assert_equal ".txt", File.extname(tempfile.path)
        assert_equal uploaded_file.read, tempfile.read
        tempfile
      end
      assert_nil tempfile.path
    end

    it "temporarily downloads IO-like objects" do
      file = @shrine.with_file(fakeio("content")) do |file|
        assert_instance_of File, file
        assert_equal "content", file.read
        file
      end
      refute File.exist?(file.path)
    end
  end

  describe "#initialize" do
    it "accepts symbol storage name" do
      uploader = @shrine.new(:store)

      assert_equal :store, uploader.storage_key
      assert_equal @uploader.storage, uploader.storage
    end

    it "accepts string storage name" do
      uploader = @shrine.new("store")

      assert_equal :store, uploader.storage_key
      assert_equal @uploader.storage, uploader.storage
    end

    it "fetches storage lazily" do
      uploader = @shrine.new(:store)

      @shrine.storages[:store] = Shrine::Storage::Memory.new

      assert_equal @shrine.storages[:store], uploader.storage
    end

    it "raises an error on unknown storage" do
      assert_raises(Shrine::Error) { @shrine.new(:foo) }
    end
  end

  it "has #storage_key, #storage and #opts" do
    assert_equal :store,                   @uploader.storage_key
    assert_equal @shrine.storages[:store], @uploader.storage
    assert_equal Hash.new,                 @uploader.opts
  end

  describe "#upload" do
    it "uploads the file to storage" do
      file = @uploader.upload(fakeio("file"))

      assert file.exists?
      assert_equal "file", file.read
    end

    it "raises Shrine::InvalidFile when input is not an IO-like object" do
      assert_raises Shrine::InvalidFile do
        @uploader.upload(:not_io)
      end
    end

    it "stores basic metadata" do
      io = fakeio("file", filename: "nature.jpg", content_type: "image/jpeg")

      file = @uploader.upload(io)

      assert_equal Hash[
        "size"      => 4,
        "filename"  => "nature.jpg",
        "mime_type" => "image/jpeg",
      ], file.metadata
    end

    it "copies metadata from UploadedFile objects" do
      uploaded_file = @uploader.upload(fakeio)
      uploaded_file.metadata.clear

      file = @uploader.upload(uploaded_file)

      assert_equal Hash.new, file.metadata
      refute_equal uploaded_file.metadata.object_id, file.metadata.object_id
    end

    it "accepts additional metadata" do
      io = fakeio("file", filename: "nature.jpg", content_type: "image/jpeg")

      file = @uploader.upload(io, metadata: { "filename" => "overridden.jpg", "foo" => "bar" })

      assert_equal Hash[
        "size"      => 4,
        "filename"  => "overridden.jpg",
        "mime_type" => "image/jpeg",
        "foo"       => "bar",
      ], file.metadata
    end

    it "skips metadata extraction on metadata: false" do
      @uploader.expects(:extract_metadata).never

      file = @uploader.upload(fakeio, metadata: false)

      assert_equal Hash.new, file.metadata
    end

    it "forces metadata extraction on metadata: true" do
      uploaded_file = @uploader.upload(fakeio)
      uploaded_file.metadata.clear

      file = @uploader.upload(uploaded_file, metadata: true)

      assert_equal %w[filename size mime_type], file.metadata.keys
      refute_equal uploaded_file.metadata.object_id, file.metadata.object_id
    end

    it "forwards options for metadata extraction" do
      io = fakeio

      @uploader.expects(:extract_metadata).with(io, foo: "bar").returns({})

      @uploader.upload(io, foo: "bar")
    end

    it "uses result of #generate_location for upload location" do
      @uploader.instance_eval do
        def get_location(io, **)
          "foo"
        end
      end

      file = @uploader.upload(fakeio)

      assert_equal "foo", file.id
    end

    it "forwards metadata for location generation" do
      @uploader.instance_eval do
        def generate_location(io, **options)
          options[:metadata].to_s
        end
      end

      file = @uploader.upload(fakeio)

      assert_equal file.metadata.to_s, file.id
    end

    it "forwards options for location generation" do
      @uploader.instance_eval do
        def generate_location(io, **options)
          options[:foo]
        end
      end

      file = @uploader.upload(fakeio, foo: "bar")

      assert_equal "bar", file.id
    end

    it "accepts :location" do
      @uploader.expects(:generate_location).never

      file = @uploader.upload(fakeio, location: "foo")

      assert_equal "foo", file.id
    end

    it "raises exception when upload location was nil" do
      @uploader.instance_eval do
        def generate_location(io, **options)
          nil
        end
      end

      assert_raises Shrine::Error do
        @uploader.upload(fakeio)
      end
    end

    it "forwards metadata to the storage" do
      @uploader.storage.expects(:upload).with do |*, o|
        o[:shrine_metadata].keys.sort == %w[filename mime_type size]
      end

      @uploader.upload(fakeio)
    end

    it "forwards :upload_options to the storage" do
      @uploader.storage.expects(:upload).with do |*, o|
        o.delete(:shrine_metadata)
        o == { foo: "bar" }
      end

      @uploader.upload(fakeio, upload_options: { foo: "bar" })
    end

    it "returns instance of correct UploadedFile" do
      file = @uploader.upload(fakeio)

      assert_instance_of @shrine::UploadedFile, file
    end

    it "closes the file after uploading" do
      @uploader.upload(io = fakeio)

      assert_raises(IOError) { io.read }
    end

    it "accepts :close option" do
      @uploader.upload(io = fakeio, close: false)

      assert_equal "", io.read
    end

    it "accepts :delete option" do
      @uploader.upload(file = tempfile("file"))
      assert File.exist?(file.path)

      @uploader.upload(file = tempfile("file"), delete: true)
      refute File.exist?(file.path)

      @uploader.upload(file = tempfile("file").tap(&File.method(:unlink)), delete: true)
      refute File.exist?(file.path)

      @uploader.upload(file = File.open(tempfile("file").path), delete: true)
      refute File.exist?(file.path)

      @uploader.upload(fakeio, delete: true)
      refute File.exist?(file.path)
    end

    it "doesn't error when storage already closed the file" do
      @uploader.storage.instance_eval { def upload(io, id, **); super; io.close; end }
      @uploader.upload(fakeio)
    end

    it "accepts IO objects of unknown size" do
      io = StringIO.new
      io.instance_eval { undef size }
      uploaded_file = @uploader.upload(io)
      assert_equal "", uploaded_file.read

      io = StringIO.new
      io.instance_eval { def size; nil; end }
      uploaded_file = @uploader.upload(io)
      assert_equal "", uploaded_file.read
    end

    it "accepts input which satisfies IO interface through #method_missing" do
      delegator_class = Class.new do
        def initialize(object)
          @object = object
        end

        def method_missing(name, *args, &block)
          @object.send(name, *args, &block)
        end

        def respond_to_missing?(name, include_private = false)
          @object.respond_to?(name, include_private) || super
        end
      end

      io = delegator_class.new(fakeio)

      @uploader.upload(io)
    end
  end

  describe "#generate_location" do
    it "creates a unique location" do
      file1 = @uploader.upload(fakeio)
      file2 = @uploader.upload(fakeio)

      refute file1.id == file2.id
    end

    it "preserves the extension" do
      # Rails file
      file = @uploader.upload(fakeio(filename: "avatar.jpg"))
      assert_match /\.jpg$/, file.id

      # Uploaded file
      uploaded_file = @uploader.upload(fakeio, location: "avatar.jpg")
      file = @uploader.upload(uploaded_file)
      assert_match /\.jpg$/, file.id

      # File
      file = @uploader.upload(File.open(__FILE__))
      assert_match /\.rb$/, file.id
    end

    it "uses filename metadata" do
      file = @uploader.upload(fakeio, metadata: { "filename" => "avatar.jpg" })
      assert_match /\.jpg$/, file.id
    end

    it "downcases the extension" do
      file = @uploader.upload(fakeio(filename: "avatar.JPG"))
      assert_match /\.jpg$/, file.id
    end

    it "handles no extension or no filename" do
      file = @uploader.upload(fakeio(filename: "avatar"))
      assert_match /^[\w-]+$/, file.id

      uploaded_file = @uploader.upload(fakeio, location: "avatar")
      file = @uploader.upload(uploaded_file)
      assert_match /^[\w-]+$/, file.id

      file = @uploader.upload(fakeio)
      assert_match /^[\w-]+$/, file.id
    end

    it "gets extension from shrine-url-style id with query params" do
      uploaded_file = @uploader.upload(fakeio, location: "http://example.com/path.html?key=value")
      file = @uploader.upload(uploaded_file)
      assert_match /\.html$/, file.id

      uploaded_file = @uploader.upload(fakeio, location: "http://example.com/path?key=value")
      file = @uploader.upload(uploaded_file)
      refute_match /key=value/, file.id
      assert_match /^[\w-]+$/, file.id
    end
  end

  describe "#extract_metadata" do
    it "extracts the filename" do
      metadata = @uploader.extract_metadata(fakeio(filename: "avatar.jpg"))
      assert_equal "avatar.jpg", metadata["filename"]

      metadata = @uploader.extract_metadata(File.open("Gemfile"))
      assert_equal "Gemfile", metadata["filename"]

      metadata = @uploader.extract_metadata(fakeio)
      assert_nil metadata["filename"]
    end

    it "extracts the filesize" do
      metadata = @uploader.extract_metadata(fakeio("image"))
      assert_equal 5, metadata["size"]
    end

    it "extracts the mime type" do
      metadata = @uploader.extract_metadata(fakeio(content_type: "image/jpeg"))
      assert_equal "image/jpeg", metadata["mime_type"]

      metadata = @uploader.extract_metadata(fakeio(content_type: "text/plain;charset=utf-8"))
      assert_equal "text/plain", metadata["mime_type"]

      metadata = @uploader.extract_metadata(fakeio)
      assert_nil metadata["mime_type"]

      metadata = @uploader.extract_metadata(image)
      assert_nil metadata["mime_type"]
    end

    it "successfully extracts metadata from another UploadedFile" do
      io            = fakeio("avatar", filename: "foo.jpg", content_type: "image/jpeg")
      uploaded_file = @uploader.upload(io)
      metadata      = @uploader.extract_metadata(uploaded_file)

      assert_equal 6,            metadata["size"]
      assert_equal "foo.jpg",    metadata["filename"]
      assert_equal "image/jpeg", metadata["mime_type"]
    end
  end
end
