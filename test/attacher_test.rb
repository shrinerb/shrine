require "test_helper"
require "json"

# TODO: If a user selects a file, and then deselects it, a nil/false-value will
# be sent, and prepare to handle that in a way that you simply ignore it

class AttacherTest < Minitest::Test
  def setup
    @uploadie = uploader(:bare).class
    @user = Struct.new(:avatar_data).new
    @attacher = @uploadie::Attacher.new(@user, :avatar)
  end

  test "setting caches a given IO" do
    uploaded_file = @attacher.set(fakeio("image"))

    assert_instance_of @uploadie::UploadedFile, uploaded_file
    assert_equal "cache", uploaded_file.data["storage"]
    assert_equal "image", uploaded_file.read
  end

  test "setting writes to record's data attribute" do
    @attacher.set(fakeio("image"))

    JSON.parse @user.avatar_data
  end

  test "allows setting already uploaded files with an UploadedFile" do
    uploaded_file = @uploadie.new(:cache).upload(fakeio)
    @attacher.set(uploaded_file)

    assert_instance_of @uploadie::UploadedFile, @attacher.get
  end

  test "setting cached files doesn't recache them" do
    uploaded_file = @uploadie.new(:cache).upload(fakeio)
    @attacher.set uploaded_file

    assert_equal uploaded_file.id, @attacher.get.id
  end

  test "setting stored files doesn't cache them" do
    uploaded_file = @uploadie.new(:store).upload(fakeio)
    @attacher.set uploaded_file

    assert_equal uploaded_file.id, @attacher.get.id
  end

  test "setting to nil nullifies the attachment" do
    @attacher.set(fakeio)
    @attacher.set(nil)

    assert_equal nil, @attacher.get
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
    def uploader.generate_location(io, name:, record:); "foo" end
    @attacher.set(fakeio)
  end

  test "commiting uploads the cached file to the store" do
    @attacher.set(fakeio)
    @attacher.commit!

    assert_equal :store, @attacher.get.storage_key
  end

  test "commmiting deletes removed files" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.set(nil)
    @attacher.commit!

    refute uploaded_file.exists?
  end

  test "commiting deletes replaced files" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.set(fakeio)
    @attacher.commit!

    refute uploaded_file.exists?
  end

  test "commiting doesn't reupload UploadedFiles from store" do
    @attacher.set(fakeio)
    @attacher.commit!
    uploaded_file = @attacher.get

    @attacher.commit!

    assert_equal uploaded_file.id, @attacher.get.id
  end

  test "url" do
    assert_equal nil, @attacher.url

    @attacher.set(fakeio)

    assert_match %r{^memory://}, @attacher.url
  end
end
