require "test_helper"

describe "the extension plugin" do
  before do
    @uploader = uploader { plugin :extension }
  end

  it "adds #extension to the uploaded file" do
    uploaded_file = @uploader.upload(fakeio(filename: "avatar.jpg"))

    assert_equal "jpg", uploaded_file.extension
  end

  it "returns nil if there is no extension" do
    uploaded_file = @uploader.upload(fakeio(filename: "avatar"))

    assert_equal nil, uploaded_file.extension
  end
end
