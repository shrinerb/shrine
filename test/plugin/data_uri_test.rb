require "test_helper"

class DataUriTest < Minitest::Test
  def setup
    @attacher = attacher { plugin :data_uri, error_message: ->(uri) { "Data URI failed" } }
  end

  test "enables caching with a data URI" do
    @attacher.data_uri = data_uri

    assert @attacher.get
    refute_empty @attacher.get.read
    assert_equal "image/png", @attacher.get.content_type
    assert @attacher.get.size > 0
  end

  test "defaults content type to text/plain" do
    @attacher.data_uri = data_uri(nil)

    assert_equal "text/plain", @attacher.get.content_type
  end

  test "allows content types with dots in them" do
    @attacher.data_uri = data_uri("image/vnd.microsoft.icon")

    assert_equal "image/vnd.microsoft.icon", @attacher.get.content_type
  end

  test "setting an empty string is a noop" do
    @attacher.data_uri = data_uri
    @attacher.data_uri = ""

    assert @attacher.get
  end

  test "adds a validation error if data_uri wasn't properly matched" do
    @attacher.data_uri = "bla"

    assert_equal ["Data URI failed"], @attacher.errors
  end

  test "record interface" do
    user = @attacher.record
    user.avatar_data_uri = data_uri

    assert @attacher.get
    assert_respond_to user, :avatar_data_uri
  end
end
