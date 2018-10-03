require "test_helper"

describe Shrine do
  before do
    @uploader = uploader
    @shrine = @uploader.class
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

  describe ".attachment" do
    it "returns an instance of Attachment" do
      uploader = Class.new(Shrine)
      uploader.storages = {cache: "cache", store: "store"}
      assert_instance_of uploader::Attachment, uploader.attachment(:avatar)
      assert_instance_of uploader::Attachment, uploader[:avatar]
    end
  end

  describe ".uploaded_file" do
    it "accepts data as Hash" do
      uploaded_file = @uploader.upload(fakeio)
      retrieved = @shrine.uploaded_file(uploaded_file.data)
      assert_equal uploaded_file, retrieved
    end

    it "accepts data as JSON" do
      uploaded_file = @uploader.upload(fakeio)
      retrieved = @shrine.uploaded_file(uploaded_file.to_json)
      assert_equal uploaded_file, retrieved
    end

    it "accepts an UploadedFile" do
      uploaded_file = @uploader.upload(fakeio)
      retrieved = @shrine.uploaded_file(uploaded_file)
      assert_equal uploaded_file, retrieved
    end

    it "yields the converted file" do
      uploaded_file = @uploader.upload(fakeio)
      @shrine.uploaded_file(uploaded_file.data) { |o| @yielded = o }
      assert_equal uploaded_file, @yielded
    end

    it "raises an error on invalid input" do
      assert_raises(Shrine::Error) { @shrine.uploaded_file(:foo) }
    end
  end

  describe ".find_storage" do
    it "finds by symbol names" do
      assert_equal @uploader.storage, @shrine.find_storage(:store)
    end

    it "finds by string names" do
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
      tempfile = Tempfile.new("")
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
    it "accepts symbol and string storage names" do
      uploader = @shrine.new(:store)
      assert_equal :store, uploader.storage_key
      assert_equal @uploader.storage, uploader.storage

      uploader = @shrine.new("store")
      assert_equal :store, uploader.storage_key
      assert_equal @uploader.storage, uploader.storage
    end

    it "raises an error on unknown storage" do
      assert_raises(Shrine::Error) { @shrine.new(:foo) }
    end
  end

  it "has #storage_key, #storage and #opts" do
    assert_equal :store, @uploader.storage_key
    assert_equal @shrine.storages[:store], @uploader.storage
    assert_equal Hash.new, @uploader.opts
  end

  describe "#upload" do
    it "stores the file" do
      uploaded_file = @uploader.upload(fakeio("original"))
      assert uploaded_file.exists?
      assert_equal "original", uploaded_file.read
    end

    it "calls the processing" do
      @uploader.instance_eval { def process(io, context); FakeIO.new(io.read.reverse); end }
      uploaded_file = @uploader.upload(fakeio("original"))
      assert_equal "lanigiro", uploaded_file.read
    end

    it "sends the context all the way down" do
      @uploader.instance_eval do
        def process(io, context); FakeIO.new(context[:foo]); end
        def generate_location(io, context); context[:foo]; end
        def extract_metadata(io, context); {"foo" => context[:foo]}; end
      end
      uploaded_file = @uploader.upload(fakeio, {foo: "bar"})
      assert_equal "bar", uploaded_file.read
      assert_equal "bar", uploaded_file.id
      assert_equal "bar", uploaded_file.metadata["foo"]
    end

    it "doesn't mutate context" do
      @uploader.upload(fakeio, {}.freeze)
    end
  end

  describe "#store" do
    it "returns instance of correct UploadedFile" do
      uploaded_file = @uploader.store(fakeio)
      assert_instance_of @shrine::UploadedFile, uploaded_file
    end

    it "uploads the file without processing" do
      @uploader.instance_eval { def process(io, context); FakeIO.new(io.read.reverse); end }
      uploaded_file = @uploader.store(fakeio("original"))
      assert_equal "original", uploaded_file.read
    end

    it "uses :location if available" do
      uploaded_file = @uploader.store(fakeio, location: "foo")
      assert_equal "foo", uploaded_file.id
    end

    it "calls #generate_location if :location isn't provided" do
      @uploader.instance_eval { def generate_location(io, context); "foo"; end }
      uploaded_file = @uploader.store(fakeio)
      assert_equal "foo", uploaded_file.id
    end

    it "raises Shrine::Error when generated location was nil" do
      @uploader.instance_eval { def generate_location(io, context); nil; end }
      assert_raises(Shrine::Error) { @uploader.store(fakeio) }
    end

    it "extracts and assigns metadata" do
      photo = fakeio("photo", filename: "nature.jpg", content_type: "image/jpeg")
      uploaded_file = @uploader.store(photo)
      assert_equal 5,            uploaded_file.metadata["size"]
      assert_equal "nature.jpg", uploaded_file.metadata["filename"]
      assert_equal "image/jpeg", uploaded_file.metadata["mime_type"]
    end

    it "allows setting metadata manually" do
      photo = fakeio("photo", filename: "random")
      uploaded_file = @uploader.store(photo, metadata: { "filename" => "nature.jpg", "foo" => "bar" })
      assert_equal "nature.jpg", uploaded_file.metadata["filename"]
      assert_equal "bar",        uploaded_file.metadata["foo"]
    end

    it "copies metadata from other UploadedFiles" do
      another_uploaded_file = @uploader.store(fakeio)
      another_uploaded_file.metadata["foo"] = "bar"
      uploaded_file = @uploader.store(another_uploaded_file)
      assert_equal "bar", uploaded_file.metadata["foo"]
    end

    it "closes the file after uploading" do
      @uploader.store(io = fakeio)
      assert_raises(IOError) { io.read }
    end

    it "doesn't error when storage already closed the file" do
      @uploader.storage.instance_eval { def upload(io, *); super; io.close; end }
      @uploader.store(fakeio)
    end

    it "checks if the input is a valid IO" do
      assert_raises(Shrine::InvalidFile) { @uploader.store(:not_an_io) }
    end

    it "accepts IO objects with unknown size" do
      io = StringIO.new
      io.instance_eval { undef size }
      uploaded_file = @uploader.store(io)
      assert_equal "", uploaded_file.read

      io = StringIO.new
      io.instance_eval { def size; nil; end }
      uploaded_file = @uploader.store(io)
      assert_equal "", uploaded_file.read
    end

    it "passes objects which satisfy IO interface through #method_missing" do
      delegator_class = Struct.new(:object) do
        def method_missing(name, *args, &block)
          object.send(name, *args, &block)
        end

        def respond_to?(name, include_private = false)
          object.respond_to?(name, include_private) || super
        end
      end

      @uploader.store(delegator_class.new(fakeio))
    end
  end

  describe "#uploaded?" do
    it "returns true if storages match" do
      cached_file = @shrine.new(:cache).upload(fakeio)
      assert @shrine.new(:cache).uploaded?(cached_file)
      refute @shrine.new(:store).uploaded?(cached_file)
    end
  end

  describe "#delete" do
    it "deletes the given file" do
      uploaded_file = @uploader.upload(fakeio)
      deleted_file = @uploader.delete(uploaded_file)
      refute deleted_file.exists?
      assert_equal uploaded_file, deleted_file
    end
  end

  describe "#generate_location" do
    it "creates a unique location" do
      location1 = @uploader.generate_location(fakeio)
      location2 = @uploader.generate_location(fakeio)
      refute location1 == location2
    end

    it "preserves the extension" do
      # Rails file
      location = @uploader.generate_location(fakeio(filename: "avatar.jpg"))
      assert_match /\.jpg$/, location

      # Uploaded file
      uploaded_file = @uploader.upload(fakeio, location: "avatar.jpg")
      location = @uploader.generate_location(uploaded_file)
      assert_match /\.jpg$/, location

      # File
      location = @uploader.generate_location(File.open(__FILE__))
      assert_match /\.rb$/, location
    end

    it "downcases the extension" do
      location = @uploader.generate_location(fakeio(filename: "avatar.JPG"))
      assert_match /\.jpg$/, location
    end

    it "handles no extension or no filename" do
      location = @uploader.generate_location(fakeio(filename: "avatar"))
      assert_match /^[\w-]+$/, location

      uploaded_file = @uploader.upload(fakeio, location: "avatar")
      location = @uploader.generate_location(uploaded_file)
      assert_match /^[\w-]+$/, location

      location = @uploader.generate_location(fakeio)
      assert_match /^[\w-]+$/, location
    end

    it "can access extracted metadata" do
      @uploader.instance_eval do
        def generate_location(io, context)
          @metadata = context[:metadata]
          super
        end
      end
      uploaded_file = @uploader.upload(fakeio)
      assert_equal uploaded_file.metadata, @uploader.instance_variable_get("@metadata")
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

    it "extracts the content type" do
      metadata = @uploader.extract_metadata(fakeio(content_type: "image/jpeg"))
      assert_equal "image/jpeg", metadata["mime_type"]

      metadata = @uploader.extract_metadata(fakeio)
      assert_nil metadata["mime_type"]
    end

    it "successfully extracts metadata from another UploadedFile" do
      file = fakeio("avatar", filename: "foo.jpg", content_type: "image/jpeg")
      uploaded_file = @uploader.upload(file)
      metadata = @uploader.extract_metadata(uploaded_file)
      assert_equal 6,            metadata["size"]
      assert_equal "foo.jpg",    metadata["filename"]
      assert_equal "image/jpeg", metadata["mime_type"]
    end
  end
end
