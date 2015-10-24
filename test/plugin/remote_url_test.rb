require "test_helper"

describe "the remote_url plugin" do
  include TestHelpers::Interactions

  def cassette
    "interactions"
  end

  def attacher(**options)
    options[:error_message] ||= "Download failed"
    options[:max_size] ||= nil
    super() { plugin :remote_url, **options }
  end

  before do
    @attacher = attacher
    @user = @attacher.record
  end

  it "enables attaching a file via a remote url" do
    @user.avatar_remote_url = image_url

    assert_instance_of @attacher.shrine_class::UploadedFile, @user.avatar
  end

  it "keeps the remote url value if uploading doesn't succeed" do
    @user.avatar_remote_url = image_url
    assert_equal nil, @user.avatar_remote_url

    @user.avatar_remote_url = "foo"
    assert_equal "foo", @user.avatar_remote_url
  end

  it "ignores empty urls" do
    @user.avatar_remote_url = ""

    assert_equal nil, @user.avatar_remote_url
    assert_equal nil, @user.avatar
  end

  it "rescues download errors" do
    @user.avatar_remote_url = invalid_url

    assert_equal invalid_url, @user.avatar_remote_url
    assert_equal nil, @user.avatar
  end

  it "adds download errors as validation errors" do
    @user.avatar_remote_url = image_url
    assert_empty @attacher.errors

    @user.avatar_remote_url = invalid_url
    assert_equal ["Download failed"], @attacher.errors
  end

  it "doesn't nullify the existing attachment on download error" do
    @attacher.assign(fakeio)
    @attacher.record.avatar_remote_url = invalid_url

    refute_equal nil, @attacher.record.avatar
  end

  it "accepts error message as a block" do
    @attacher = attacher(error_message: ->(url) { "Message" })
    @attacher.record.avatar_remote_url = invalid_url

    assert_equal ["Message"], @attacher.errors
  end

  it "accepts custom downloader" do
    @attacher = attacher(downloader: ->(url, **) { fakeio(url) })
    @attacher.record.avatar_remote_url = "foo"

    assert_equal "foo", @attacher.record.avatar.read
  end

  it "defaults downloader to :open_uri" do
    assert_equal :open_uri, @attacher.shrine_class.opts[:remote_url_downloader]
  end

  it "accepts :max_size" do
    @attacher = attacher(max_size: 5)
    @attacher.record.avatar_remote_url = image_url

    assert_equal ["Download failed"], @attacher.errors
  end
end
