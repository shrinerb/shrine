require "test_helper"

class PreserveFilenameTest < Minitest::Test
  def setup
    @uploader = uploader(:preserve_filename)
  end

  test "uses the unique location as the directory" do
    # original_filename
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"))
    assert_match /^[\w-]+\/foo\.jpg$/, uploaded_file.id

    # id
    second_uploaded_file = @uploader.upload(uploaded_file)
    assert_match /^[\w-]+\/foo\.jpg$/, second_uploaded_file.id

    # path
    uploaded_file = @uploader.upload(File.open("Gemfile"))
    assert_match /^[\w-]+\/Gemfile$/, uploaded_file.id
  end

  test "falls back to original location generating if filename cannot be extracted" do
    uploaded_file = @uploader.upload(fakeio)

    assert_match /^[\w-]+$/, uploaded_file.id
  end
end
