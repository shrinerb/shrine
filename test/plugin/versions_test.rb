require "test_helper"

describe "versions plugin" do
  before do
    @attacher = attacher { plugin :versions, names: [:thumb] }
    @uploader = @attacher.store
  end

  it "allows uploading versions" do
    versions = @uploader.upload(thumb: fakeio)

    assert_kind_of Shrine::UploadedFile, versions.fetch(:thumb)
  end

  it "allows processing into versions" do
    @uploader.singleton_class.class_eval do
      def process(io, context)
        {thumb: FakeIO.new(io.read.reverse)}
      end
    end
    versions = @uploader.upload(fakeio("original"))

    assert_equal "lanigiro", versions.fetch(:thumb).read
  end

  it "allows reprocessing versions" do
    @uploader.singleton_class.class_eval do
      def process(hash, context)
        {thumb: FakeIO.new(hash.fetch(:thumb).read.reverse)}
      end
    end
    versions = @uploader.upload(thumb: fakeio("thumb"))

    assert_equal "bmuht", versions.fetch(:thumb).read
  end

  it "makes #uploaded_file recognize versions" do
    versions = @uploader.upload(thumb: fakeio)
    retrieved = @uploader.class.uploaded_file(versions.to_json)

    assert_equal versions, retrieved
  end

  it "passes the version name to location generator" do
    @uploader.class.class_eval do
      def generate_location(io, version:)
        version.to_s
      end
    end
    versions = @uploader.upload(thumb: fakeio)

    assert_equal "thumb", versions.fetch(:thumb).id
  end

  it "overrides #uploaded?" do
    versions = @uploader.upload(thumb: fakeio)

    assert @uploader.uploaded?(versions)
  end

  it "enables deleting versions" do
    versions = @uploader.upload(thumb: fakeio)
    deleted_versions = @uploader.delete(versions)

    assert_equal versions, deleted_versions
    refute deleted_versions[:thumb].exists?
  end

  describe "Attacher#url" do
    it "accepts a version name" do
      uploaded_file = @uploader.upload(fakeio)
      @attacher.set("thumb" => uploaded_file.data)

      assert_equal uploaded_file.url, @attacher.url(:thumb)
    end

    it "returns nil when a attachment doesn't exist" do
      assert_equal nil, @attacher.url(:thumb)
    end

    it "fails explicity when version isn't registered" do
      uploaded_file = @uploader.upload(fakeio)
      @attacher.set("thumb" => uploaded_file.data)

      assert_raises(Shrine::Error) { @attacher.url(:unknown) }
    end

    it "doesn't fail if version is registered but missing" do
      @attacher.set({})
      @attacher.singleton_class.class_eval do
        def default_url(options)
          "missing #{options[:version]}"
        end
      end

      assert_equal "missing thumb", @attacher.url(:thumb)
    end

    it "returns raw file URL if versions haven't been generated" do
      @attacher.set(fakeio)

      assert_equal @attacher.url, @attacher.url(:thumb)
    end

    it "doesn't allow no argument when attachment is versioned" do
      uploaded_file = @uploader.upload(fakeio)
      @attacher.set("thumb" => uploaded_file.data)

      assert_raises(Shrine::Error) { @attacher.url }
    end

    it "passes in :version to the default url" do
      @uploader.class.class_eval do
        def default_url(context)
          context.fetch(:version).to_s
        end
      end

      assert_equal "thumb", @attacher.url(:thumb)
    end

    it "forwards url options" do
      @attacher.cache.storage.singleton_class.class_eval do
        def url(id, **options)
          options
        end
      end
      @attacher.shrine_class.class_eval do
        def default_url(context)
          context
        end
      end

      uploaded_file = @attacher.set(fakeio)
      @attacher.set("thumb" => uploaded_file.data)
      assert_equal Hash[foo: "foo"], @attacher.url(:thumb, foo: "foo")

      @attacher.set(fakeio)
      assert_equal Hash[foo: "foo"], @attacher.url(:thumb, foo: "foo")

      @attacher.set(nil)
      assert_equal Hash[foo: "foo", name: :avatar, record: @attacher.record],
                   @attacher.url(foo: "foo")
      assert_equal Hash[version: :thumb, foo: "foo", name: :avatar, record: @attacher.record],
                   @attacher.url(:thumb, foo: "foo")
    end
  end

  it "doesn't allow validating versions" do
    @attacher.class.validate {}
    uploaded_file = @uploader.upload(fakeio)

    assert_raises(Shrine::Error) { @attacher.set("thumb" => uploaded_file.data) }
  end

  describe "Attacher" do
    it "returns a hash of versions" do
      uploaded_file = @uploader.upload(fakeio)
      @attacher.set("thumb" => uploaded_file.data)

      assert_kind_of Shrine::UploadedFile, @attacher.get.fetch(:thumb)
    end

    it "destroys versions successfully" do
      uploaded_file = @uploader.upload(fakeio)
      @attacher.set("thumb" => uploaded_file.data)

      @attacher.destroy

      refute uploaded_file.exists?
    end

    it "replaces versions sucessfully" do
      uploaded_file = @uploader.upload(fakeio)
      @attacher.set("thumb" => uploaded_file.data)

      @attacher.set("thumb" => @uploader.upload(fakeio).data)
      @attacher.replace

      refute uploaded_file.exists?
    end

    it "promotes versions successfully" do
      cached_file = @attacher.set("thumb" => @uploader.upload(fakeio).data)
      @attacher.promote(cached_file)

      assert @attacher.store.uploaded?(@attacher.get[:thumb])
    end

    it "filters the hash to only registered version" do
      uploaded_file = @uploader.upload(fakeio)
      @attacher.set("thumb" => uploaded_file.data, "malicious" => uploaded_file.data)

      assert_equal [:thumb], @attacher.get.keys
    end
  end

  it "still catches invalid IOs" do
    @uploader.singleton_class.class_eval do
      def process(io, context)
        {thumb: "invalid IO"}
      end
    end

    assert_raises(Shrine::InvalidFile) { @uploader.upload(fakeio) }
  end
end
