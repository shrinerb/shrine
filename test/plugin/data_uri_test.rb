require "test_helper"
require "base64"

describe "the data_uri plugin" do
  def setup
    @attacher = attacher { plugin :data_uri, error_message: ->(uri) { "Data URI failed" } }
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

  it "defaults content type to text/plain" do
    @user.avatar_data_uri = data_uri(nil)

    assert_equal "text/plain", @user.avatar.mime_type
  end

  it "allows content types with dots and pluses in them" do
    @user.avatar_data_uri = data_uri("application/vnd.api+json")

    assert_equal "application/vnd.api+json", @user.avatar.mime_type
  end

  it "doesn't allow content types with other special characters" do
    @user.avatar_data_uri = data_uri("application/vnd.api&json")

    assert @user.avatar.nil?
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

  it "adds a validation error if data_uri wasn't properly matched" do
    @user.avatar_data_uri = "bla"

    assert_equal ["Data URI failed"], @user.avatar_attacher.errors
  end

  it "adds a #data_uri method to uploaded files" do
    @user.avatar = fakeio(Base64.decode64("somefile"))

    assert_equal "data:text/plain;base64,somefile", @user.avatar.data_uri
  end
end
