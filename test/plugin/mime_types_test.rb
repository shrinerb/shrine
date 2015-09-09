require "test_helper"

class MimeTypesTest < Minitest::Test
  def setup
    @uploader = uploader(:mime_types)
  end

  test "determines content type from file extension" do
    uploaded_file = @uploader.upload(fakeio(filename: "image.png"))

    assert_equal "image/png", uploaded_file.content_type
  end

  test "doesn't trip when it can't determine the content type" do
    uploaded_file = @uploader.upload(fakeio(filename: "image.foo"))

    assert_equal nil, uploaded_file.content_type
  end

  test "doesn't trip when there is no filename" do
    uploaded_file = @uploader.upload(fakeio)

    assert_equal nil, uploaded_file.content_type
  end
end
