require "test_helper"
require "json"

describe Shrine::Attacher do
  before do
    @attacher = attacher
  end

  describe "#assign" do
    it "caches the object if it's an IO" do
      @attacher.assign(fakeio("image"))
      assert_instance_of @attacher.shrine_class::UploadedFile, @attacher.get
      assert_equal "cache", @attacher.get.data["storage"]
      assert_equal "image", @attacher.get.read
    end

    it "caches to different locations when repeated" do
      @attacher.assign(fakeio)
      uploaded_file1 = @attacher.get
      @attacher.assign(fakeio)
      uploaded_file2 = @attacher.get
      refute_equal uploaded_file1.id, uploaded_file2.id
    end

    it "passes context hash on caching" do
      io = fakeio
      context = {name: @attacher.name, record: @attacher.record, phase: :cache}
      @attacher.cache.expects(:upload).with(io, context)
      @attacher.assign(io)
    end

    it "accepts already uploaded files via a JSON string" do
      cached_file = @attacher.cache.upload(fakeio)
      @attacher.assign(cached_file.to_json)
      assert_equal cached_file, @attacher.get
    end

    it "rejects stored files for security reasons" do
      stored_file = @attacher.store.upload(fakeio)
      @attacher.assign(stored_file.to_json)
      assert_equal nil, @attacher.get
    end

    it "accepts nils" do
      @attacher.assign(fakeio)
      @attacher.assign(nil)
      assert_equal nil, @attacher.get
    end

    it "ignores empty strings" do
      @attacher.assign(fakeio)
      @attacher.assign("")
      assert @attacher.get
    end
  end

  describe "#set" do
    it "writes to record's data attribute" do
      @attacher.assign(fakeio)
      assert_equal @attacher.get.to_json, @attacher.record.avatar_data
    end

    it "nullifies the attachment if nil is passed in" do
      @attacher.assign(fakeio)
      @attacher.set(nil)
      assert_equal nil, @attacher.get
      assert_equal nil, @attacher.record.avatar_data
    end

    it "doesn't dirty if attachment didn't change" do
      @attacher.record.avatar_data = @attacher.cache.upload(fakeio).to_json
      @attacher.set(@attacher.get)
      refute @attacher.attached?
    end

    it "allows setting stored files" do
      stored_file = @attacher.store.upload(fakeio)
      @attacher.set(stored_file)
      assert @attacher.get
    end

    it "runs validations" do
      @attacher.class.validate { errors << :foo }
      @attacher.assign(fakeio)
      refute_empty @attacher.errors
    end
  end

  describe "#get" do
    it "reads from the database column" do
      uploaded_file = @attacher.cache.upload(fakeio)

      @attacher.record.avatar_data = uploaded_file.data.to_json
      assert_instance_of @attacher.shrine_class::UploadedFile, @attacher.get

      @attacher.record.avatar_data = uploaded_file.data # serialized
      assert_instance_of @attacher.shrine_class::UploadedFile, @attacher.get
    end

    it "returns nil when column is blank" do
      @attacher.record.avatar_data = nil
      assert_equal nil, @attacher.get

      @attacher.record.avatar_data = ""
      assert_equal nil, @attacher.get
    end
  end

  describe "#_promote" do
    it "calls #promote if assigned file is cached" do
      cached_file = @attacher.cache.upload(fakeio)
      @attacher.record.avatar_data = cached_file.to_json
      @attacher.expects(:promote)
      @attacher._promote
    end

    it "doesn't call #promote if assigned file is not cached" do
      stored_file = @attacher.store.upload(fakeio)
      @attacher.record.avatar_data = stored_file.to_json
      @attacher.expects(:promote).never
      @attacher._promote
    end

    it "doesn't call #promote if no file is assigned" do
      @attacher.expects(:promote).never
      @attacher._promote
    end
  end

  describe "#promote" do
    it "uploads the cached file to store" do
      @attacher.assign(fakeio)
      @attacher.promote(@attacher.get)
      assert_equal "store", @attacher.get.storage_key
      assert @attacher.get.exists?
    end

    it "passes context hash on storing" do
      io = fakeio
      context = {name: @attacher.name, record: @attacher.record, phase: :store}
      @attacher.assign(io)
      @attacher.store.expects(:upload).with(@attacher.get, context).returns(true)
      @attacher._promote
    end

    it "returns the promoted file" do
      @attacher.assign(fakeio)
      stored_file = @attacher.promote(@attacher.get)
      assert_equal @attacher.get, stored_file
    end

    it "deletes stored file if swapping failed" do
      @attacher.instance_eval do
        def swap(uploaded_file)
          @stored_file = uploaded_file
          nil
        end
      end
      @attacher.assign(fakeio)
      @attacher.promote(@attacher.get)
      refute @attacher.instance_variable_get("@stored_file").exists?
    end
  end

  describe "#replace" do
    it "deletes replaced files" do
      @attacher.set(uploaded_file = @attacher.store.upload(fakeio))
      @attacher.set(@attacher.store.upload(fakeio))
      @attacher.replace
      refute uploaded_file.exists?
    end

    it "passes context hash to delete" do
      context = {name: @attacher.name, record: @attacher.record, phase: :replaced}
      @attacher.set(@attacher.store.upload(fakeio))
      @attacher.store.expects(:delete).with(@attacher.get, context)
      @attacher.set(nil)
      @attacher.replace
    end

    it "doesn't trip if there was no previous file" do
      @attacher.set(@attacher.store.upload(fakeio))
      @attacher.replace
    end

    it "doesn't replace cached files" do
      @attacher.set(cached_file = @attacher.cache.upload(fakeio))
      @attacher.replace
      assert cached_file.exists?
    end
  end

  describe "#destroy" do
    it "deletes the attached file" do
      @attacher.set(@attacher.store.upload(fakeio))
      @attacher.destroy
      refute @attacher.get.exists?
    end

    it "passes context hash to delete" do
      context = {name: @attacher.name, record: @attacher.record, phase: :destroyed}
      @attacher.set(@attacher.store.upload(fakeio))
      @attacher.store.expects(:delete).with(@attacher.get, context)
      @attacher.destroy
    end

    it "doesn't trip if file doesn't exist" do
      @attacher.destroy
    end

    it "doesn't delete cached files" do
      @attacher.set(@attacher.cache.upload(fakeio))
      @attacher.destroy
      assert @attacher.get.exists?
    end
  end

  describe "#url" do
    it "calls storage's #url" do
      assert_equal nil, @attacher.url
      @attacher.assign(fakeio)
      assert_equal "memory://#{@attacher.get.id}", @attacher.url
    end

    it "forwards options to uploaded file's #url" do
      @attacher.cache.storage.instance_eval { def url(id, **opts); opts.to_json; end }
      @attacher.assign(fakeio)
      assert_equal '{"foo":"bar"}', @attacher.url(foo: "bar")
    end

    it "calls #default_url when attachment is missing" do
      @attacher.shrine_class.plugin(:default_url) { |c| c[:foo] }
      assert_equal "bar", @attacher.url(foo: "bar")
    end
  end

  describe "#validate" do
    it "instance exec's the validation block" do
      @attacher.class.validate { errors << get.read }
      @attacher.assign(fakeio("image"))
      assert_equal ["image"], @attacher.errors
    end

    it "doesn't run validations when there is no attachment" do
      @attacher.class.validate { errors << :foo }
      @attacher.validate
      assert_empty @attacher.errors
    end

    it "clears existing errors" do
      @attacher.errors << [:foo]
      @attacher.validate
      assert_empty @attacher.errors
    end
  end
end
