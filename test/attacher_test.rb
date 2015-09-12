require "test_helper"
require "json"

class AttacherTest < Minitest::Test
  def setup
    @uploadie = uploader(:bare).class
    @user = Struct.new(:avatar_data).new
    @attacher = @uploadie::Attacher.new(@user, :avatar)
  end

  test "setting caches the given IO" do
    uploaded_file = @attacher.set(fakeio("image"))

    assert_instance_of @uploadie::UploadedFile, uploaded_file
    assert_equal "cache", uploaded_file.data["storage"]
    assert_equal "image", uploaded_file.read
  end

  test "setting writes to record's data attribute" do
    @attacher.set(fakeio("image"))

    JSON.parse @user.avatar_data
  end

  test "allows setting already uploaded file with a JSON string" do
    uploaded_file = @uploadie.new(:cache).upload(fakeio)
    @attacher.set(uploaded_file.data.to_json)

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

    assert_instance_of @uploadie::UploadedFile, @attacher.get
  end

  test "getting reads from the database column" do
    uploaded_file = @uploadie.new(:cache).upload(fakeio)

    @user.avatar_data = uploaded_file.data.to_json
    assert_instance_of @uploadie::UploadedFile, @attacher.get

    @user.avatar_data = uploaded_file.data # serialized
    assert_instance_of @uploadie::UploadedFile, @attacher.get
  end

  test "getting returns nil for nil-column" do
    assert_equal nil, @attacher.get
  end

  test "caching passes in name and record" do
    uploader = @attacher.cache
    def uploader.generate_location(io, name:, record:); "foo"; end
    @attacher.set(fakeio)
  end

  test "saving uploads the cached file to the store" do
    @attacher.set(fakeio)
    @attacher.save

    assert_equal :store, @attacher.get.storage_key
  end

  test "saving deletes removed files" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.set(nil)
    @attacher.save

    refute uploaded_file.exists?
  end

  test "saving deletes replaced files" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.set(fakeio)
    @attacher.save

    refute uploaded_file.exists?
  end

  test "saving doesn't reupload UploadedFiles from store" do
    @attacher.set(fakeio)
    @attacher.save
    uploaded_file = @attacher.get

    @attacher.save

    assert_equal uploaded_file.id, @attacher.get.id
  end

  test "destroying deletes attached file" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.destroy

    refute uploaded_file.exists?
  end

  test "destroying doesn't trip if file doesn't exist" do
    @attacher.destroy
  end

  test "url" do
    assert_equal nil, @attacher.url

    @attacher.set(fakeio)

    assert_match %r{^memory://}, @attacher.url
  end

  test "default url" do
    uploader = @attacher.store
    def uploader.default_url(context); "#{context[:name]}_default"; end

    assert_equal "avatar_default", @attacher.url
  end

  test "validation" do
    assert @attacher.valid?

    @attacher.uploadie_class.validate { errors << :foo }

    refute @attacher.valid?
  end
end
