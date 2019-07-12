require "test_helper"
require "shrine/plugins/remote_url"

describe Shrine::Plugins::RemoteUrl do
  before do
    @attacher = attacher { plugin :remote_url, max_size: nil }
    @shrine = @attacher.shrine_class
    @user = @attacher.record

    Down.stubs(:download).with(good_url, max_size: nil).returns(StringIO.new("file"))
    Down.stubs(:download).with(bad_url, max_size: nil).raises(Down::Error.new("file not found"))
  end

  it "enables attaching a file via a remote url" do
    @user.avatar_remote_url = good_url
    assert @user.avatar
    assert_equal "file", @user.avatar.read
  end

  it "keeps the remote url value if downloading doesn't succeed" do
    @user.avatar_remote_url = good_url
    assert_nil @user.avatar_remote_url
    @user.avatar_remote_url = bad_url
    assert_equal bad_url, @user.avatar_remote_url
  end

  it "aborts assignment on download errors" do
    @user.avatar = fakeio
    @user.avatar_remote_url = bad_url
    assert @user.avatar
  end

  it "ignores empty urls" do
    @user.avatar = fakeio
    @user.avatar_remote_url = ""
    assert @user.avatar
    assert_nil @user.avatar_remote_url
  end

  it "ignores nil values" do
    @user.avatar = fakeio
    @user.avatar_remote_url = nil
    assert @user.avatar
    assert_nil @user.avatar_remote_url
  end

  it "accepts :max_size" do
    @shrine.plugin :remote_url, max_size: 1
    Down.stubs(:download).with(good_url, max_size: 1).raises(Down::TooLarge.new("file is too large"))
    @user.avatar_remote_url = good_url
    refute @user.avatar
  end

  it "accepts custom downloader" do
    @shrine.plugin :remote_url, downloader: ->(url, **){fakeio(url)}
    @user.avatar_remote_url = "foo"
    assert_equal "foo", @user.avatar.read
  end

  it "defaults downloader to :open_uri" do
    assert_equal :open_uri, @attacher.shrine_class.opts[:remote_url][:downloader]
  end

  it "accepts additional downloader options" do
    @shrine.plugin :remote_url, downloader: ->(url, max_size:, **options){fakeio(options.to_s)}
    @attacher.assign_remote_url(good_url, downloader: { foo: "bar" })
    assert_equal "{:foo=>\"bar\"}", @user.avatar.read
  end

  it "accepts additional uploader options" do
    @attacher.assign_remote_url(good_url, location: "foo")
    assert_equal "foo", @attacher.get.id
  end

  it "transforms download errors into validation errors" do
    @user.avatar_remote_url = good_url
    assert_empty @user.avatar_attacher.errors

    @user.avatar_remote_url = bad_url
    assert_equal ["download failed: file not found"], @user.avatar_attacher.errors

    @shrine.plugin :remote_url, max_size: 1
    Down.stubs(:download).with(good_url, max_size: 1).raises(Down::TooLarge.new("file is too large"))
    @user.avatar_remote_url = good_url
    assert_equal ["download failed: file is too large"], @user.avatar_attacher.errors
  end

  it "accepts custom error message" do
    @shrine.plugin :remote_url, error_message: "download failed"
    @user.avatar_remote_url = bad_url
    assert_equal ["download failed"], @user.avatar_attacher.errors

    @shrine.plugin :remote_url, error_message: ->(url){"download failed: #{url}"}
    @user.avatar_remote_url = bad_url
    assert_equal ["download failed: #{bad_url}"], @user.avatar_attacher.errors

    @shrine.plugin :remote_url, error_message: ->(url, error){error.message}
    @user.avatar_remote_url = bad_url
    assert_equal ["file not found"], @user.avatar_attacher.errors
  end

  it "has a default error message when downloader returns nil" do
    @shrine.plugin :remote_url, downloader: ->(url, **){nil}
    @user.avatar_remote_url = good_url
    assert_equal ["download failed"], @user.avatar_attacher.errors
  end

  it "clears any existing errors" do
    @user.avatar_attacher.errors << "foo"
    @user.avatar_remote_url = bad_url
    refute_includes @user.avatar_attacher.errors, "foo"
  end

  def good_url
    "http://example.com/good.jpg"
  end

  def bad_url
    "http://example.com/bad.jpg"
  end
end
