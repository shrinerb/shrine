require "test_helper"

class RackFileTest < Minitest::Test
  def setup
    @uploader = uploader { plugin :rack_file }
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

  test "accepts any other options Rack might add in the future" do
    @uploader.upload(tempfile: fakeio, name: "bar")
  end

  test "works on attacher" do
    @attacher = attacher { plugin :rack_file }

    uploaded_file = @attacher.set(tempfile: fakeio)

    assert_kind_of Shrine::UploadedFile, uploaded_file
  end
end
