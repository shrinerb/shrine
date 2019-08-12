require "test_helper"

describe Shrine::Attacher do
  before do
    @attacher = attacher
    @shrine   = @attacher.shrine_class
  end

  describe ".from_data" do
    it "instantiates an attacher from file data" do
      file     = @attacher.upload(fakeio)
      attacher = @shrine::Attacher.from_data(file.data)
      assert_equal file, attacher.file
    end

    it "forwards additional options to .new" do
      attacher = @shrine::Attacher.from_data(nil, cache: :other_cache)
      assert_equal :other_cache, attacher.cache_key
    end
  end

  describe "#assign" do
    it "attaches a file to cache" do
      @attacher.assign(fakeio)
      assert_equal :cache,  @attacher.file.storage_key
    end

    it "returns the cached file" do
      file = @attacher.assign(fakeio)
      assert_equal @attacher.file, file
    end

    it "ignores empty strings" do
      @attacher.assign(fakeio)
      @attacher.assign("")
      assert @attacher.attached?
    end

    it "accepts nil" do
      @attacher.assign(fakeio)
      @attacher.assign(nil)
      refute @attacher.attached?
    end

    it "fowards any additional options for upload" do
      @attacher.assign(fakeio, location: "foo")
      assert_equal "foo", @attacher.file.id
    end
  end

  describe "#attach_cached" do
    describe "with IO object" do
      it "caches an IO object" do
        @attacher.attach_cached(fakeio)
        assert_equal :cache,  @attacher.file.storage_key
      end

      it "caches an UploadedFile object" do
        cached_file = @shrine.upload(fakeio, :cache)
        @attacher.attach_cached(cached_file)
        refute_equal cached_file.id, @attacher.file.id
      end

      it "returns the attached file" do
        file = @attacher.attach_cached(fakeio)
        assert_equal @attacher.file, file
      end

      it "uploads to attacher's temporary storage" do
        @attacher = @shrine::Attacher.new(cache: :other_cache)
        @attacher.attach_cached(fakeio)
        assert_equal :other_cache, @attacher.file.storage_key
      end

      it "accepts nils" do
        @attacher.attach_cached(fakeio)
        @attacher.attach_cached(nil)
        assert_nil @attacher.file
      end

      it "passes :action as :cache" do
        io = fakeio
        @attacher.shrine_class.expects(:upload).with(io, :cache, { action: :cache })
        @attacher.attach_cached(io)
      end

      it "forwards additional options for upload" do
        @attacher.attach_cached(fakeio, location: "foo")
        assert_equal "foo", @attacher.file.id
      end
    end

    describe "with uploaded file data" do
      it "accepts JSON data of a cached file" do
        cached_file = @shrine.upload(fakeio, :cache)
        @attacher.attach_cached(cached_file.to_json)
        assert_equal cached_file, @attacher.file
      end

      it "accepts Hash data of a cached file" do
        cached_file = @shrine.upload(fakeio, :cache)
        @attacher.attach_cached(cached_file.data)
        assert_equal cached_file, @attacher.file
      end

      it "changes the attachment" do
        cached_file = @shrine.upload(fakeio, :cache)
        @attacher.attach_cached(cached_file.data)
        assert @attacher.changed?
      end

      it "returns the attached file" do
        cached_file = @shrine.upload(fakeio, :cache)
        assert_equal cached_file, @attacher.attach_cached(cached_file.data)
      end

      it "uses attacher's temporary storage" do
        @attacher = @shrine::Attacher.new(cache: :other_cache)
        cached_file = @shrine.upload(fakeio, :other_cache)
        @attacher.attach_cached(cached_file.data)
        assert_equal :other_cache, @attacher.file.storage_key
      end

      it "rejects non-cached files" do
        stored_file = @shrine.upload(fakeio, :store)
        assert_raises(Shrine::Error) do
          @attacher.attach_cached(stored_file.data)
        end
      end
    end
  end

  describe "#attach" do
    it "uploads the file to permanent storage" do
      @attacher.attach(fakeio)
      assert @attacher.file.exists?
      assert_equal :store, @attacher.file.storage_key
    end

    it "uses attacher's permanent storage" do
      @attacher = @shrine::Attacher.new(store: :other_store)
      @attacher.attach(fakeio)
      assert_equal :other_store, @attacher.file.storage_key
    end

    it "allows specifying a different storage" do
      @attacher.attach(fakeio, storage: :other_store)
      assert @attacher.file.exists?
      assert_equal :other_store, @attacher.file.storage_key
    end

    it "forwards additional options for upload" do
      @attacher.attach(fakeio, location: "foo")
      assert_equal "foo", @attacher.file.id
    end

    it "returns the uploaded file" do
      file = @attacher.attach(fakeio)
      assert_equal @attacher.file, file
    end

    it "changes the attachment" do
      @attacher.attach(fakeio)
      assert @attacher.changed?
    end

    it "accepts nil" do
      @attacher.attach(fakeio)
      @attacher.attach(nil)
      assert_nil @attacher.file
    end
  end

  describe "#finalize" do
    it "promotes cached file" do
      @attacher.attach_cached(fakeio)
      @attacher.finalize
      assert_equal :store, @attacher.file.storage_key
    end

    it "deletes previous file" do
      previous_file = @attacher.attach(fakeio)
      @attacher.attach(fakeio)
      @attacher.finalize
      refute previous_file.exists?
    end

    it "clears dirty state" do
      @attacher.attach(fakeio)
      @attacher.finalize
      refute @attacher.changed?
    end
  end

  describe "#promote_cached" do
    it "uploads cached file to permanent storage" do
      @attacher.attach_cached(fakeio)
      @attacher.promote_cached
      assert_equal :store, @attacher.file.storage_key
    end

    it "doesn't promote if file is not cached" do
      file = @attacher.attach(fakeio, storage: :other_store)
      @attacher.promote_cached
      assert_equal file, @attacher.file
    end

    it "doesn't promote if attachment has not changed" do
      file = @shrine.upload(fakeio, :cache)
      @attacher.file = file
      @attacher.promote_cached
      assert_equal file, @attacher.file
    end

    it "sets :action to :store" do
      file = @attacher.attach_cached(fakeio)
      @attacher.shrine_class.expects(:upload).with(file, :store, { action: :store })
      @attacher.promote_cached
    end

    it "forwards additional options for upload" do
      @attacher.attach_cached(fakeio)
      @attacher.promote_cached(location: "foo")
      assert_equal "foo", @attacher.file.id
    end
  end

  describe "#promote" do
    it "uploads attached file to permanent storage" do
      @attacher.attach_cached(fakeio)
      @attacher.promote
      assert_equal :store, @attacher.file.storage_key
      assert @attacher.file.exists?
    end

    it "returns the promoted file" do
      @attacher.attach_cached(fakeio)
      file = @attacher.promote
      assert_equal @attacher.file, file
    end

    it "allows uploading to a different storage" do
      @attacher.attach(fakeio)
      @attacher.promote(storage: :other_store)
      assert_equal :other_store, @attacher.file.storage_key
      assert @attacher.file.exists?
    end

    it "forwards additional options for upload" do
      @attacher.attach_cached(fakeio)
      @attacher.promote(location: "foo")
      assert_equal "foo", @attacher.file.id
    end

    it "doesn't change the attachment" do
      @attacher.file = @attacher.upload(fakeio)
      @attacher.promote
      refute @attacher.changed?
    end
  end

  describe "#upload" do
    it "uploads file to permanent storage" do
      uploaded_file = @attacher.upload(fakeio)
      assert_instance_of @shrine::UploadedFile, uploaded_file
      assert uploaded_file.exists?
      assert_equal :store, uploaded_file.storage_key
    end

    it "uploads file to specified storage" do
      uploaded_file = @attacher.upload(fakeio, :other_store)
      assert_equal :other_store, uploaded_file.storage_key
    end

    it "forwards context hash" do
      @attacher.context[:foo] = "bar"
      io = fakeio
      @attacher.shrine_class.expects(:upload).with(io, :store, @attacher.context)
      @attacher.upload(io)
    end

    it "forwards additional options" do
      uploaded_file = @attacher.upload(fakeio, metadata: { "foo" => "bar" })
      assert_equal "bar", uploaded_file.metadata["foo"]
    end
  end

  describe "#destroy_previous" do
    it "deletes previous attached file" do
      previous_file = @attacher.attach(fakeio)
      @attacher.attach(fakeio)
      @attacher.destroy_previous
      refute previous_file.exists?
      assert @attacher.file.exists?
    end

    it "deletes only stored files" do
      previous_file = @attacher.attach_cached(fakeio)
      @attacher.attach(fakeio)
      @attacher.destroy_previous
      assert previous_file.exists?
      assert @attacher.file.exists?
    end

    it "handles previous attachment being nil" do
      @attacher.attach(fakeio)
      @attacher.destroy_previous
      assert @attacher.file.exists?
    end

    it "skips when attachment hasn't changed" do
      @attacher.file = @attacher.upload(fakeio)
      @attacher.destroy_previous
      assert @attacher.file.exists?
    end
  end

  describe "#destroy_attached" do
    it "deletes stored file" do
      @attacher.file = @shrine.upload(fakeio, :other_store)
      @attacher.destroy_attached
      refute @attacher.file.exists?
    end

    it "doesn't delete cached files" do
      @attacher.file = @shrine.upload(fakeio, :cache)
      @attacher.destroy_attached
      assert @attacher.file.exists?
    end

    it "handles no attached file" do
      @attacher.destroy_attached
    end
  end

  describe "#destroy" do
    it "deletes attached file" do
      @attacher.file = @attacher.upload(fakeio)
      @attacher.destroy
    end

    it "handles no attached file" do
      @attacher.destroy
    end
  end

  describe "#change" do
    it "sets the uploaded file" do
      file = @attacher.upload(fakeio)
      @attacher.change(file)
      assert_equal file, @attacher.file
    end

    it "returns the uploaded file" do
      file = @attacher.upload(fakeio)
      assert_equal file, @attacher.change(file)
    end

    it "marks attacher as changed" do
      file = @attacher.upload(fakeio)
      @attacher.change(file)
      assert @attacher.changed?
    end

    it "doesn't mark attacher as changed on same file" do
      @attacher.file = @attacher.upload(fakeio)
      @attacher.change(@attacher.file)
      refute @attacher.changed?
    end
  end

  describe "#set" do
    it "sets the uploaded file" do
      file = @attacher.upload(fakeio)
      @attacher.set(file)
      assert_equal file, @attacher.file
    end

    it "returns the set file" do
      file = @attacher.upload(fakeio)
      assert_equal file, @attacher.set(file)
    end

    it "doesn't mark attacher as changed" do
      @attacher.set @attacher.upload(fakeio)
      refute @attacher.changed?
    end
  end

  describe "#get" do
    it "returns the attached file" do
      @attacher.attach(fakeio)
      assert_equal @attacher.file, @attacher.get
    end

    it "returns nil when no file is attached" do
      assert_nil @attacher.get
    end
  end

  describe "#url" do
    it "returns the attached file URL" do
      @attacher.attach(fakeio)
      assert_equal @attacher.file.url, @attacher.url
    end

    it "returns nil when no file is attached" do
      assert_nil @attacher.url
    end

    it "forwards additional URL options" do
      @attacher.attach(fakeio)
      @attacher.file.expects(:url).with(foo: "bar")
      @attacher.url(foo: "bar")
    end
  end

  describe "changed?" do
    it "returns true when the attachment has changed to another file" do
      @attacher.attach(fakeio)
      assert_equal true, @attacher.changed?
    end

    it "returns true when the attachment has changed to nil" do
      @attacher.file = @attacher.upload(fakeio)
      @attacher.attach(nil)
      assert_equal true, @attacher.changed?
    end

    it "returns false when attachment hasn't changed" do
      @attacher.file = @attacher.upload(fakeio)
      assert_equal false, @attacher.changed?
    end
  end

  describe "#attached?" do
    it "returns true when file is attached" do
      @attacher.attach(fakeio)
      assert_equal true, @attacher.attached?
    end

    it "returns false when file is not attached" do
      assert_equal false, @attacher.attached?
      @attacher.attach(nil)
      assert_equal false, @attacher.attached?
    end
  end

  describe "#cached?" do
    it "returns true when attached file is present and cached" do
      @attacher.file = @shrine.upload(fakeio, :cache)
      assert_equal true, @attacher.cached?
    end

    it "returns true when specified file is present and cached" do
      assert_equal true, @attacher.cached?(@shrine.upload(fakeio, :cache))
    end

    it "returns false when attached file is present and stored" do
      @attacher.file = @shrine.upload(fakeio, :store)
      assert_equal false, @attacher.cached?
    end

    it "returns false when specified file is present and stored" do
      assert_equal false, @attacher.cached?(@shrine.upload(fakeio, :store))
    end

    it "returns false when no file is attached" do
      assert_equal false, @attacher.cached?
    end

    it "returns false when specified file is nil" do
      assert_equal false, @attacher.cached?(nil)
    end
  end

  describe "#stored?" do
    it "returns true when attached file is present and stored" do
      @attacher.file = @shrine.upload(fakeio, :store)
      assert_equal true, @attacher.stored?
    end

    it "returns true when specified file is present and stored" do
      assert_equal true, @attacher.stored?(@shrine.upload(fakeio, :store))
    end

    it "returns false when attached file is present and cached" do
      @attacher.file = @shrine.upload(fakeio, :cache)
      assert_equal false, @attacher.stored?
    end

    it "returns false when specified file is present and cached" do
      assert_equal false, @attacher.stored?(@shrine.upload(fakeio, :cache))
    end

    it "returns false when no file is attached" do
      assert_equal false, @attacher.stored?
    end

    it "returns false when specified file is nil" do
      assert_equal false, @attacher.stored?(nil)
    end
  end

  describe "#data" do
    it "returns file data when file is attached" do
      file = @attacher.attach(fakeio)
      assert_equal file.data, @attacher.data
    end

    it "returns nil when no file is attached" do
      assert_nil @attacher.data
    end
  end

  describe "#load_data" do
    it "loads file from given file data" do
      file = @attacher.upload(fakeio)
      @attacher.load_data(file.data)
      assert_equal file, @attacher.file
    end

    it "handles symbol keys" do
      file = @attacher.upload(fakeio)
      @attacher.load_data(
        id:       file.id,
        storage:  file.storage_key,
        metadata: file.metadata,
      )
      assert_equal file, @attacher.file
    end

    it "clears file when given data is nil" do
      @attacher.file = @attacher.upload(fakeio)
      @attacher.load_data(nil)
      assert_nil @attacher.file
    end
  end

  describe "#file=" do
    it "sets the file" do
      file = @attacher.upload(fakeio)
      @attacher.file = file
      assert_equal file, @attacher.file
    end

    it "accepts nil" do
      @attacher.attach(fakeio)
      @attacher.file = nil
      assert_nil @attacher.file
    end

    it "raises error on other arguments" do
      assert_raises(ArgumentError) do
        @attacher.file = :foo
      end
    end
  end

  describe "#file" do
    it "returns the set file" do
      file = @attacher.upload(fakeio)
      @attacher.file = file
      assert_equal file, @attacher.file
    end
  end

  describe "#upload_file" do
    it "instantiates an uploaded file with JSON data" do
      file = @attacher.upload(fakeio)
      assert_equal file, @attacher.uploaded_file(file.to_json)
    end

    it "instantiates an uploaded file with Hash data" do
      file = @attacher.upload(fakeio)
      assert_equal file, @attacher.uploaded_file(file.data)
    end

    it "returns file with UploadedFile" do
      file = @attacher.upload(fakeio)
      assert_equal file, @attacher.uploaded_file(file)
    end
  end

  it "has smarter .inspect" do
    assert_includes @attacher.class.inspect, "::Attacher"
  end
end
