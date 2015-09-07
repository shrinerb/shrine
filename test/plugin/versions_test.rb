require "test_helper"

class VersionsTest < Minitest::Test
  def setup
    @uploader = uploader(:versions) do
      def _generate_location(io, context)
        (context[:type] || super).to_s
      end
    end
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
    uploaded_file = @uploader.upload(fakeio("image"), {type: :avatar})

    assert_equal "avatar", uploaded_file.id
    assert_equal "image", @storage.read(uploaded_file.id)
  end
end
