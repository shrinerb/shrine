require "test_helper"

describe "preserve_filename plugin" do
  before do
    @uploader = uploader { plugin :preserve_filename }
  end

  it "uses the original location as the directory" do
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

  it "falls back to original location generating if filename cannot be extracted" do
    uploaded_file = @uploader.upload(fakeio)

    assert_match /^[\w-]+$/, uploaded_file.id
  end

  it "doesn't use the filename if the IO is a Tempfile" do
    uploaded_file = @uploader.upload(Tempfile.new("foobar"))

    refute_match "foobar", uploaded_file.id
  end
end
