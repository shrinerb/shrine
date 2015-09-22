require "test_helper"
require "json"

class AttacherTest < Minitest::Test
  def setup
    @attacher = attacher
  end

  test "setting caches the given IO" do
    uploaded_file = @attacher.set(fakeio("image"))

    assert_instance_of @attacher.shrine_class::UploadedFile, uploaded_file
    assert_equal "cache", uploaded_file.data["storage"]
    assert_equal "image", uploaded_file.read
  end

  test "setting writes to record's data attribute" do
    @attacher.set(fakeio("image"))

    JSON.parse @attacher.record.avatar_data
  end

  test "allows setting already uploaded file with a JSON string" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.set(uploaded_file.data.to_json)

    assert_equal uploaded_file, @attacher.get
  end

  test "allows setting already uploaded file with a Hash of data" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.set(uploaded_file.data)

    assert_equal uploaded_file, @attacher.get
  end

  test "setting to nil nullifies the attachment" do
    @attacher.set(fakeio)
    @attacher.set(nil)

    assert_equal nil, @attacher.get
  end

  test "setting to empty string is a noop" do
    @attacher.set(fakeio)
    @attacher.set("")

    assert_kind_of Shrine::UploadedFile, @attacher.get
  end

  test "getting reads from the database column" do
    uploaded_file = @attacher.set(fakeio)

    @attacher.record.avatar_data = uploaded_file.data.to_json
    assert_instance_of @attacher.shrine_class::UploadedFile, @attacher.get

    @attacher.record.avatar_data = uploaded_file.data # serialized
    assert_instance_of @attacher.shrine_class::UploadedFile, @attacher.get
  end

  test "getting returns nil for nil-column" do
    assert_equal nil, @attacher.get
  end

  test "#replace deletes removed files" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.set(nil)
    @attacher.replace

    refute uploaded_file.exists?
  end

  test "#replace deletes replaced files" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.set(fakeio)
    @attacher.replace

    refute uploaded_file.exists?
  end

  test "#replace doesn't trip if there was no previous file" do
    @attacher.set(nil)
    @attacher.replace
  end

  test "#promote uploads the cached file to the store" do
    @attacher.set(fakeio)
    @attacher.promote(@attacher.get)

    assert_equal "store", @attacher.get.storage_key
  end

  test "#promote keeps the cached file" do
    cached_file = @attacher.set(fakeio)
    @attacher.promote(@attacher.get)

    assert cached_file.exists?
  end

  test "#promote doesn't assign stored file if cached files don't match" do
    cached_file = @attacher.set(fakeio)
    another_cached_file = @attacher.set(fakeio)
    @attacher.promote(cached_file)

    assert another_cached_file, @attacher.get
  end

  test "#promote? returns true if uploaded file is present and cached" do
    refute @attacher.promote?(nil)
    refute @attacher.promote?(@attacher.store.upload(fakeio))
    assert @attacher.promote?(@attacher.cache.upload(fakeio))
  end

  test "destroying deletes attached file" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.destroy

    refute uploaded_file.exists?
  end

  test "destroying doesn't trip if file doesn't exist" do
    @attacher.destroy
  end

  test "caching and storing passes in name and record" do
    @attacher.shrine_class.class_eval do
      def generate_location(io, context)
        context.keys.to_json
      end
    end

    @attacher.set(fakeio)
    assert_equal '["name","record"]', @attacher.get.id

    @attacher.promote(@attacher.get)
    assert_equal '["name","record"]', @attacher.get.id
  end

  test "url" do
    assert_equal nil, @attacher.url

    @attacher.set(fakeio)

    assert_match %r{^memory://}, @attacher.url
  end

  test "forwards url options to the uploaded file" do
    @attacher.cache.storage.singleton_class.class_eval do
      def url(id, **options)
        options
      end
    end
    @attacher.set(fakeio)

    assert_equal Hash[foo: "foo"], @attacher.url(foo: "foo")
  end

  test "default url" do
    @attacher.shrine_class.class_eval do
      def default_url(context)
        "#{context[:name]}_default"
      end
    end

    assert_equal "avatar_default", @attacher.url
  end

  test "forwards url options to default url" do
    @attacher.shrine_class.class_eval do
      def default_url(context)
        context
      end
    end

    assert_equal Hash[name: :avatar, record: @attacher.record, foo: "foo"],
                 @attacher.url(foo: "foo")
  end

  test "does validation on assignment" do
    @attacher.shrine_class.validate { errors << :foo }
    @attacher.set(fakeio)

    refute_empty @attacher.errors
  end

  test "validation block has access to the cached file" do
    @attacher.shrine_class.validate { errors << get.read }
    @attacher.set(fakeio("image"))

    assert_equal "image", @attacher.errors.first
  end

  test "validation doesn't happen when attachment is empty" do
    @attacher.shrine_class.validate { errors << :foo }

    assert_empty @attacher.errors
  end

  test "errors are cleared before validation" do
    @attacher.errors << [:foo]
    @attacher.set(fakeio)
    assert_empty @attacher.errors

    @attacher.errors << [:foo]
    @attacher.set(nil)
    assert_empty @attacher.errors
  end
end
