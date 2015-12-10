require "test_helper"

describe Shrine do
  before do
    @uploader = uploader
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
    it "accepts data as JSON string" do
      uploaded_file = @uploader.upload(fakeio)
      retrieved = @uploader.class.uploaded_file(uploaded_file.to_json)

      assert_equal uploaded_file, retrieved
    end

    it "accepts data as Hash" do
      uploaded_file = @uploader.upload(fakeio)
      retrieved = @uploader.class.uploaded_file(uploaded_file.data)

      assert_equal uploaded_file, retrieved
    end

    it "accepts an UploadedFile" do
      uploaded_file = @uploader.upload(fakeio)
      retrieved = @uploader.class.uploaded_file(uploaded_file)

      assert_equal uploaded_file, retrieved
    end

    it "yields the converted file" do
      uploaded_file = @uploader.upload(fakeio)
      @uploader.class.uploaded_file(uploaded_file.data) { |o| @yielded = o }

      assert_equal uploaded_file, @yielded
    end

    it "raises an error on invalid input" do
      assert_raises(Shrine::Error) { @uploader.class.uploaded_file(:foo) }
    end
  end

  describe ".find_storage" do
    it "finds by symbol names" do
      assert_equal @uploader.storage, @uploader.class.find_storage(:store)
    end

    it "finds by string names" do
      assert_equal @uploader.storage, @uploader.class.find_storage("store")
    end

    it "raises an error if storage wasn't found" do
      assert_raises(Shrine::Error) { @uploader.class.find_storage(:foo) }
    end
  end

  describe "#initialize" do
    it "symbolizes storage key" do
      shrine = Class.new(Shrine)
      shrine.storages = {foo: "bar"}

      uploader = shrine.new("foo")

      assert_equal :foo, uploader.storage_key
    end

    it "raises an error on missing storage" do
      assert_raises(Shrine::Error) { Shrine.new(:foo) }
    end
  end

  it "has #storage_key, #storage and #opts" do
    assert_equal :store, @uploader.storage_key
    assert_equal @uploader.class.storages[:store], @uploader.storage
    assert_equal Hash.new, @uploader.opts
  end

  describe "#upload" do
    it "stores the file" do
      uploaded_file = @uploader.upload(fakeio)

      assert uploaded_file.exists?
    end

    it "calls the processing" do
      @uploader.instance_eval do
        def process(io, context)
          FakeIO.new(io.read.reverse)
        end
      end

      uploaded_file = @uploader.upload(fakeio("original"))

      assert_equal "lanigiro", uploaded_file.read
    end
  end

  describe "#store" do
    it "uploads the file without processing" do
      @uploader.instance_eval do
        def process(io, context)
          FakeIO.new(io.read.reverse)
        end
      end

      uploaded_file = @uploader.store(fakeio("original"))

      assert_equal "original", uploaded_file.read
    end

    it "uses :location if available" do
      uploaded_file = @uploader.store(fakeio, location: "foo")

      assert_equal "foo", uploaded_file.id
    end

    it "calls #generate_location if :location isn't provided" do
      @uploader.instance_eval do
        def generate_location(io, context)
          "foo"
        end
      end
      uploaded_file = @uploader.store(fakeio)

      assert_equal "foo", uploaded_file.id
    end

    it "extracts and assigns metadata" do
      photo = fakeio("photo", filename: "nature.jpg", content_type: "image/jpeg")
      uploaded_file = @uploader.store(photo)

      assert_equal 5, uploaded_file.metadata["size"]
      assert_equal "nature.jpg", uploaded_file.metadata["filename"]
      assert_equal "image/jpeg", uploaded_file.metadata["mime_type"]
    end

    it "closes the file after uploading" do
      @uploader.store(io = fakeio)

      assert_raises(IOError) { io.read }
    end

    it "checks if the input is a valid IO" do
      assert_raises(Shrine::Error) { @uploader.store(:not_an_io) }
    end
  end

  describe "#uploaded?" do
    it "returns true if storages match" do
      cached_file = @uploader.class.new(:cache).upload(fakeio)

      assert @uploader.class.new(:cache).uploaded?(cached_file)
      refute @uploader.class.new(:store).uploaded?(cached_file)
    end
  end

  describe "#delete" do
    it "deletes the single files" do
      uploaded_file = @uploader.upload(fakeio)
      deleted_file = @uploader.delete(uploaded_file)

      assert_equal uploaded_file, deleted_file
      refute deleted_file.exists?
    end
  end

  describe "#generate_location" do
    it "creates a unique location" do
      id1 = @uploader.generate_location(fakeio)
      id2 = @uploader.generate_location(fakeio)

      refute id1 == id2
    end

    it "preserves the extension" do
      # Rails file
      location = @uploader.generate_location(fakeio(filename: "avatar.jpg"))
      assert_match /\.jpg$/, location

      # Uploaded file
      uploaded_file = @uploader.upload(fakeio(filename: "avatar.jpg"))
      location = @uploader.generate_location(uploaded_file)
      assert_match /\.jpg$/, location

      # File
      location = @uploader.generate_location(File.open(__FILE__))
      assert_match /\.rb$/, location
    end

    it "handles no filename" do
      location = @uploader.generate_location(fakeio)

      assert_match /^[\w-]+$/, location
    end
  end

  describe "#extract_metadata" do
    it "extracts the filename" do
      metadata = @uploader.extract_metadata(fakeio(filename: "avatar.jpg"))
      assert_equal "avatar.jpg", metadata["filename"]

      metadata = @uploader.extract_metadata(File.open("Gemfile"))
      assert_equal "Gemfile", metadata["filename"]

      metadata = @uploader.extract_metadata(fakeio)
      assert_equal nil, metadata.fetch("filename")
    end

    it "extracts the filesize" do
      metadata = @uploader.extract_metadata(fakeio("image"))

      assert_equal 5, metadata["size"]
    end

    it "extracts the content type" do
      metadata = @uploader.extract_metadata(fakeio(content_type: "image/jpeg"))
      assert_equal "image/jpeg", metadata["mime_type"]

      metadata = @uploader.extract_metadata(fakeio)
      assert_equal nil, metadata.fetch("mime_type")
    end

    it "successfully extracts metadata from another UploadedFile" do
      file = fakeio("avatar", filename: "foo.jpg", content_type: "image/jpeg")
      uploaded_file = @uploader.upload(file)

      metadata = @uploader.extract_metadata(uploaded_file)

      assert_equal 6, metadata["size"]
      assert_equal "foo.jpg", metadata["filename"]
      assert_equal "image/jpeg", metadata["mime_type"]
    end
  end

  it "sends the context all the way down" do
    @uploader.instance_eval do
      def process(io, foo:)
        FakeIO.new(foo)
      end

      def generate_location(io, foo:)
        foo
      end

      def extract_metadata(io, foo:)
        {"foo" => foo}
      end
    end

    uploaded_file = @uploader.upload(fakeio, {foo: "bar"})

    assert_equal "bar", uploaded_file.read
    assert_equal "bar", uploaded_file.id
    assert_equal "bar", uploaded_file.metadata["foo"]
  end
end
