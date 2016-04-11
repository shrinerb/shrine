require "test_helper"
require "base64"

describe "the data_uri plugin" do
  before do
    @attacher = attacher { plugin :data_uri }
    @user = @attacher.record
  end

  it "enables caching with a data URI" do
    @user.avatar_data_uri = data_uri
    assert @user.avatar
    refute_empty @user.avatar.read
    assert_equal "image/png", @user.avatar.mime_type
    assert @user.avatar.size > 0
  end

  it "keeps the data uri value if uploading doesn't succeed" do
    @user.avatar_data_uri = data_uri
    assert_equal nil, @user.avatar_data_uri
    @user.avatar_data_uri = "foo"
    assert_equal "foo", @user.avatar_data_uri
  end

  it "extracts valid content type" do
    @user.avatar_data_uri = data_uri(nil)
    assert_equal "text/plain", @user.avatar.mime_type

    @user.avatar_data_uri = data_uri("application/vnd.api+json")
    assert_equal "application/vnd.api+json", @user.avatar.mime_type

    @user.avatar_data_uri = data_uri("application/vnd.api&json")
    refute_empty @user.avatar_attacher.errors
    assert_equal "application/vnd.api+json", @user.avatar.mime_type
  end

  it "allows non-base64 data URIs" do
    @user.avatar_data_uri = data_uri_raw("image/png")
    assert @user.avatar
    refute_empty @user.avatar.read
    assert_equal "image/png", @user.avatar.mime_type
    assert @user.avatar.size > 0
  end

  it "ignores empty strings" do
    @user.avatar_data_uri = data_uri
    @user.avatar_data_uri = ""
    assert @user.avatar
  end

  it "can generate filenames" do
    @attacher.shrine_class.opts[:data_uri_filename] = ->(c) { "data_uri.#{c.split("/").last}" }
    @user.avatar_data_uri = data_uri("image/png")
    assert_equal "data_uri.png", @user.avatar.original_filename
    assert_match /\.png$/, @user.avatar.id
  end

  it "adds a validation error if data_uri wasn't properly matched" do
    @user.avatar_data_uri = "bla"
    assert_equal ["data URI was invalid"], @user.avatar_attacher.errors
  end

  it "clears any existing errors" do
    @user.avatar_attacher.errors << "foo"
    @user.avatar_data_uri = "bla"
    assert_equal ["data URI was invalid"], @user.avatar_attacher.errors
  end

  it "adds #data_uri and #base64 to UploadedFile" do
    @user.avatar = fakeio(Base64.decode64("somefile"))
    assert_equal "data:text/plain;base64,somefile", @user.avatar.data_uri
    assert_equal "somefile", @user.avatar.base64
  end

  def data_uri(content_type = "image/png")
    "data:#{content_type};base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
  end

  def data_uri_raw(content_type = "image/png")
    "data:#{content_type},#{Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAUA")}"
  end
end
