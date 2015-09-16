require "test_helper"

class RemoteUrlTest < Minitest::Test
  include TestHelpers::Interactions

  def uploader(downloader, **options)
    super(:bare) do
      plugin :remote_url, downloader: downloader, error_message: "Download failed", **options
    end
  end

  def attacher(*args)
    uploader = uploader(*args)
    user = Struct.new(:avatar_data).new
    uploader.class::Attacher.new(user, :avatar)
  end

  test "attaching a file via a remote url" do
    @attacher = attacher(:open_uri)
    @attacher.remote_url = image_url

    assert_instance_of @attacher.uploadie_class::UploadedFile, @attacher.get
  end

  test "ignores when url is empty" do
    @attacher = attacher(:open_uri)
    @attacher.remote_url = ""

    assert_equal nil, @attacher.remote_url
    assert_equal nil, @attacher.get
  end

  test "rescues download errors" do
    @attacher = attacher(:open_uri)
    @attacher.remote_url = invalid_url

    assert_equal invalid_url, @attacher.remote_url
    assert_equal nil, @attacher.get
  end

  test "download errors are added as validation errors" do
    @attacher = attacher(:open_uri)

    @attacher.remote_url = image_url
    assert_empty @attacher.errors

    @attacher.remote_url = invalid_url
    assert_equal ["Download failed"], @attacher.errors
  end

  test "download error doesn't nullify the existing attachment" do
    @attacher = attacher(:open_uri)

    @attacher.set(fakeio)
    @attacher.remote_url = invalid_url

    refute_equal nil, @attacher.get
  end

  test "accepts error message as a block" do
    @attacher = attacher(:open_uri, error_message: ->(url) { "Message" })
    @attacher.remote_url = invalid_url

    assert_equal ["Message"], @attacher.errors
  end

  test "accepts custom downloader" do
    @attacher = attacher ->(url) { fakeio("image") }
    @attacher.remote_url = "foo"

    assert_equal "image", @attacher.get.read
  end

  test "defaults downloader to :open_uri" do
    uploadie = Class.new(Uploadie) { plugin :remote_url, error_message: "" }

    assert_equal :open_uri, uploadie.opts[:remote_url_downloader]
  end

  test "attachment interface" do
    @attacher = attacher(:open_uri)
    @user = @attacher.record
    @user.class.include @attacher.uploadie_class[:avatar]

    @user.avatar_remote_url = image_url
    assert_instance_of @attacher.uploadie_class::UploadedFile, @user.avatar

    assert_respond_to @user, :avatar_remote_url
  end
end
