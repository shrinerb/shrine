require "test_helper"

describe "the delete_uploaded plugin" do
  before do
    @uploader = uploader { plugin :delete_uploaded }
  end

  it "deletes the file after it was uploaded" do
    @uploader.upload(tempfile = Tempfile.new(""))
    refute tempfile.path
  end

  it "doesn't attempt to delete non-files" do
    @uploader.upload(fakeio)
  end

  it "doesn't attempt to delete UploadedFiles" do
    uploaded_file = @uploader.upload(fakeio)
    @uploader.upload(uploaded_file)
    assert uploaded_file.exists?
  end

  it "accepts specifying storages" do
    @uploader.class.plugin :delete_uploaded, storages: [:store]
    @uploader.class.new(:cache).upload(tempfile = Tempfile.new(""))
    assert tempfile.path
    @uploader.class.new(:store).upload(tempfile = Tempfile.new(""))
    refute tempfile.path
  end
end
