require "test_helper"
require "json"

describe Shrine::Attacher do
  before do
    @attacher = attacher
  end

  describe "#assign" do
    it "caches the object if it's an IO" do
      uploaded_file = @attacher.assign(fakeio("image"))

      assert_instance_of @attacher.shrine_class::UploadedFile, uploaded_file
      assert_equal "cache", uploaded_file.data["storage"]
      assert_equal "image", uploaded_file.read
    end

    it "sets context during caching" do
      @attacher.cache.instance_eval do
        def process(io, context)
          FakeIO.new(context[:phase].to_s)
        end

        def generate_location(io, context)
          "#{context[:name]}/#{context[:record].class.superclass}"
        end
      end

      uploaded_file = @attacher.assign(fakeio("image"))

      assert_equal "assign", uploaded_file.read
      assert_equal "avatar/Struct", uploaded_file.id
    end

    it "accepts already uploaded files via a JSON string" do
      uploaded_file = @attacher.assign(fakeio)
      @attacher.assign(uploaded_file.data.to_json)

      assert_equal uploaded_file, @attacher.get
    end

    it "accepts already uploaded files via a Hash of data" do
      uploaded_file = @attacher.assign(fakeio)
      @attacher.assign(uploaded_file.data)

      assert_equal uploaded_file, @attacher.get
    end

    it "allows setting nil" do
      @attacher.assign(fakeio)
      @attacher.assign(nil)

      assert_equal nil, @attacher.get
    end

    it "does nothing if an empty string is passed in" do
      @attacher.assign(fakeio)
      @attacher.assign("")

      assert_kind_of Shrine::UploadedFile, @attacher.get
    end

    it "doesn't accept stored files" do
      stored_file = @attacher.store.upload(fakeio)
      @attacher.assign(stored_file.to_json)

      assert_equal nil, @attacher.get
    end
  end

  describe "#set" do
    it "writes to record's data attribute" do
      @attacher.assign(fakeio("image"))

      JSON.parse @attacher.record.avatar_data
    end

    it "runs validations" do
      @attacher.class.validate { errors << :foo }
      @attacher.assign(fakeio)

      refute_empty @attacher.errors
    end

    it "nullifies the attachment if nil is passed in" do
      @attacher.assign(fakeio)
      @attacher.set(nil)

      assert_equal nil, @attacher.get
      assert_equal nil, @attacher.record.avatar_data
    end

    it "doesn't schedule for replacing if attachment didn't change" do
      uploaded_file = @attacher.assign(fakeio)
      @attacher.set(uploaded_file)
      @attacher.set(uploaded_file)

      @attacher.replace

      assert uploaded_file.exists?
    end

    it "allows setting stored files" do
      stored_file = @attacher.store.upload(fakeio)
      @attacher.set(stored_file)

      assert_kind_of Shrine::UploadedFile, @attacher.get
    end
  end

  describe "#get" do
    it "reads from the database column" do
      uploaded_file = @attacher.assign(fakeio)

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

  describe "#promote" do
    it "uploads the cached file to store" do
      @attacher.assign(fakeio)
      @attacher.promote(@attacher.get)

      assert_equal "store", @attacher.get.storage_key
    end

    it "deletes the cached file" do
      cached_file = @attacher.assign(fakeio)
      @attacher.promote(cached_file)

      refute cached_file.exists?
    end

    it "doesn't assign stored file if cached files don't match" do
      cached_file = @attacher.assign(fakeio)
      another_cached_file = @attacher.assign(fakeio)
      @attacher.promote(cached_file)

      assert another_cached_file, @attacher.get
    end

    it "passes the context through" do
      @attacher.store.instance_eval do
        def process(io, context)
          FakeIO.new(context[:phase].to_s)
        end

        def generate_location(io, context)
          "#{context[:name]}/#{context[:record].class.superclass}"
        end
      end

      cached_file = @attacher.assign(fakeio)
      @attacher.promote(cached_file)

      assert_equal "promote", @attacher.get.read
      assert_equal "avatar/Struct", @attacher.get.id
    end
  end

  describe "#replace" do
    it "deletes removed files" do
      uploaded_file = @attacher.assign(fakeio)
      @attacher.assign(nil)
      @attacher.replace

      refute uploaded_file.exists?
    end

    it "deletes replaced files" do
      uploaded_file = @attacher.assign(fakeio)
      @attacher.assign(fakeio)
      @attacher.replace

      refute uploaded_file.exists?
    end

    it "doesn't trip if there was no previous file" do
      @attacher.assign(nil)
      @attacher.replace
    end

    it "doesn't try to delete the same file twice" do
      @attacher.assign(fakeio)
      @attacher.assign(fakeio)
      refute_equal nil, @attacher.instance_variable_get("@old_attachment")

      @attacher.replace
      assert_equal nil, @attacher.instance_variable_get("@old_attachment")

      @attacher.replace
    end

    it "sets :phase to :replace" do
      @attacher.cache.instance_eval do
        def delete(io, phase:, **context)
          super
        end
      end

      @attacher.assign(fakeio)
      @attacher.assign(nil)
      @attacher.replace
    end
  end

  describe "#destroy" do
    it "deletes the attached file" do
      uploaded_file = @attacher.assign(fakeio)
      @attacher.destroy

      refute uploaded_file.exists?
    end

    it "doesn't trip if file doesn't exist" do
      @attacher.destroy
    end

    it "sets :phase to :destroy" do
      @attacher.cache.instance_eval do
        def delete(io, phase:, **context)
          super
        end
      end

      @attacher.assign(fakeio)
      @attacher.destroy
    end
  end

  describe "#url" do
    it "calls storage's #url" do
      @attacher.assign(fakeio)

      assert_match %r{^memory://}, @attacher.url
    end

    it "calls #default_url when attachment is missing" do
      assert_equal nil, @attacher.url

      @attacher.store.instance_eval do
        def default_url(name:, record:, foo:)
          "#{name}_default"
        end
      end

      assert_equal "avatar_default", @attacher.url(foo: "bar")
    end

    it "forwards options to storage's #url" do
      @attacher.cache.storage.instance_eval do
        def url(id, **options)
          options.to_json
        end
      end
      @attacher.assign(fakeio)

      assert_equal '{"foo":"bar"}', @attacher.url(foo: "bar")
    end
  end

  describe "#validate" do
    it "instance exec's the validation block" do
      @attacher.class.validate { errors << get.read }
      @attacher.assign(fakeio("image"))

      assert_equal "image", @attacher.errors.first
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
