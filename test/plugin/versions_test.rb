require "test_helper"

class VersionsTest < Minitest::Test
  def setup
    @uploader = uploader(:versions)
  end

  test "uploading a hash of versions" do
    versions = @uploader.upload(
      original: fakeio("original"),
      thumb:    fakeio("thumb"),
    )

    assert_instance_of Hash, versions

    assert_equal "original", versions[:original].read
    assert_equal "thumb", versions[:thumb].read

    refute_equal versions[:original].id, versions[:thumb].id
  end

  test "storing a hash of versions" do
    versions = @uploader.store(
      original: fakeio("original"),
      thumb:    fakeio("thumb"),
    )

    assert_instance_of Hash, versions

    assert_equal "original", versions[:original].read
    assert_equal "thumb", versions[:thumb].read

    refute_equal versions[:original].id, versions[:thumb].id
  end

  test "regular upload" do
    uploaded_file = @uploader.upload(fakeio("image"), "location")

    assert_equal "location", uploaded_file.id
    assert_equal "image", @storage.read("location")
  end
end
