require "test_helper"

class RemoteUrlTest < Minitest::Test
  include TestHelpers::Interactions

  def uploader(**options)
    super() { plugin :remote_url, error_message: "Download failed", **options }
  end

  def setup
    @attacher = attacher
  end

  test "attaching a file via a remote url" do
    @attacher.remote_url = image_url

    assert_instance_of @attacher.shrine_class::UploadedFile, @attacher.get
  end

  test "ignores when url is empty" do
    @attacher.remote_url = ""

    assert_equal nil, @attacher.remote_url
    assert_equal nil, @attacher.get
  end

  test "rescues download errors" do
    @attacher.remote_url = invalid_url

    assert_equal invalid_url, @attacher.remote_url
    assert_equal nil, @attacher.get
  end

  test "download errors are added as validation errors" do
    @attacher.remote_url = image_url
    assert_empty @attacher.errors

    @attacher.remote_url = invalid_url
    assert_equal ["Download failed"], @attacher.errors
  end

  test "download error doesn't nullify the existing attachment" do
    @attacher.set(fakeio)
    @attacher.remote_url = invalid_url

    refute_equal nil, @attacher.get
  end

  test "accepts error message as a block" do
    @attacher = attacher(error_message: ->(url) { "Message" })
    @attacher.remote_url = invalid_url

    assert_equal ["Message"], @attacher.errors
  end

  test "accepts custom downloader" do
    @attacher = attacher(downloader: ->(url) { fakeio("image") })
    @attacher.remote_url = "foo"

    assert_equal "image", @attacher.get.read
  end

  test "defaults downloader to :open_uri" do
    assert_equal :open_uri, @attacher.shrine_class.opts[:remote_url_downloader]
  end

  test "attachment interface" do
    @user = @attacher.record

    @user.avatar_remote_url = image_url
    assert_instance_of @attacher.shrine_class::UploadedFile, @user.avatar

    assert_respond_to @user, :avatar_remote_url
  end
end
