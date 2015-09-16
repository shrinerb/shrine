require "test_helper"

class ExtractContentTypeTest < Minitest::Test
  def uploader(extractor)
    super() { plugin :extract_content_type, extractor: extractor }
  end

  test ":mime_types determines content type from file extension" do
    @uploader = uploader(:mime_types)
    uploaded_file = @uploader.upload(fakeio(filename: "image.png"))

    assert_equal "image/png", uploaded_file.content_type
  end

  test ":mime_types doesn't trip when it can't determine the content type" do
    @uploader = uploader(:mime_types)
    uploaded_file = @uploader.upload(fakeio(filename: "image.foo"))

    assert_equal nil, uploaded_file.content_type
  end

  test ":mime_types doesn't trip when there is no filename" do
    @uploader = uploader(:mime_types)
    uploaded_file = @uploader.upload(fakeio)

    assert_equal nil, uploaded_file.content_type
  end

  test ":filemagic determines content type from file contents" do
    @uploader = uploader(:filemagic)
    uploaded_file = @uploader.upload(image)

    assert_equal "image/jpeg", uploaded_file.content_type
  end

  test ":filemagic rewinds the file after reading from it" do
    @uploader = uploader(:filemagic)
    uploaded_file = @uploader.upload(file = fakeio("image"))

    assert_equal "image", file.read
  end

  test "extracting content type with custom extractor" do
    @uploader = uploader ->(io) { "foo/bar" }
    uploaded_file = @uploader.upload(fakeio)

    assert_equal "foo/bar", uploaded_file.content_type
  end
end
