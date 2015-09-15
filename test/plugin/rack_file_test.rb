require "test_helper"

class RackFileTest < Minitest::Test
  def setup
    @uploader = uploader(:rack_file)
  end

  test "enables storing Rack's uploaded file hash" do
    rack_file = {
      tempfile: fakeio("image"),
      filename: "image.jpg",
      type: "image/jpeg",
      head: "...",
    }

    uploaded_file = @uploader.upload(rack_file)

    assert_equal "image", uploaded_file.read
    assert_equal "image.jpg", uploaded_file.original_filename
    assert_equal "image/jpeg", uploaded_file.content_type
  end

  test "works with versions" do
    @uploader = uploader(:bare) do
      plugin :rack_file
      plugin :_versions
    end

    @uploader.upload(tempfile: fakeio)
  end
end
