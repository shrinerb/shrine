require "test_helper"

class UtilsTest < Minitest::Test
  include TestHelpers::Interactions

  def setup
    @utils = Shrine::Utils
  end

  test "copy_to_tempfile returns a tempfile" do
    tempfile = @utils.copy_to_tempfile("foo", fakeio)

    assert_instance_of Tempfile, tempfile
  end

  test "copy_to_tempfile rewinds the tempfile" do
    tempfile = @utils.copy_to_tempfile("foo", fakeio)

    assert_equal 0, tempfile.pos
  end

  test "copy_to_tempfile uses the basename" do
    tempfile = @utils.copy_to_tempfile("foo", fakeio)

    assert_match "foo", tempfile.path
  end

  test "copy_to_tempfile opens the tempfile in binmode" do
    tempfile = @utils.copy_to_tempfile("foo", fakeio)

    assert tempfile.binmode?
  end

  test "download downloads the file to disk" do
    tempfile = @utils.download(image_url)

    assert File.exist?(tempfile.path)
  end

  test "download exposes the original filename" do
    tempfile = @utils.download(image_url)

    assert_equal "mark-github-128.png", tempfile.original_filename
  end

  test "original filename is URI decoded" do
    tempfile = @utils.download("http://www.google.com/filename%20with%20spaces.jpg")

    assert_equal "filename with spaces.jpg", tempfile.original_filename
  end

  test "download also accepts decoded URIs with spaces" do
    tempfile = @utils.download("http://www.google.com/filename with spaces.jpg")

    assert_equal "filename with spaces.jpg", tempfile.original_filename
  end

  test "download exposes the content type" do
    tempfile = @utils.download(image_url)

    assert_equal "image/png", tempfile.content_type
  end

  test "download unifies different kinds of upload errors" do
    assert_raises(Shrine::Error) { @utils.download(invalid_url) }
  end

  test "download accepts a :max_size" do
    assert_raises(Shrine::Error) { @utils.download(image_url, max_size: 5) }
  end

  test "download raises an error when URI is invalid" do
    assert_raises(Shrine::Error) { @utils.download("foobar") }
  end

  test "download raises errors on invalid URLs" do
    assert_raises(Shrine::Error) { @utils.download("http://\\") }
    assert_raises(Shrine::Error) { @utils.download("foo://") }
  end
end
