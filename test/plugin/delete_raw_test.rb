require "test_helper"
require "shrine/plugins/delete_raw"

describe Shrine::Plugins::DeleteRaw do
  before do
    @uploader = uploader { plugin :delete_raw }
  end

  it "deletes files after upload" do
    @uploader.upload(tempfile = Tempfile.new)
    refute File.exist?(tempfile.path)
  end

  it "deletes tempfiles after upload" do
    @uploader.upload(file = File.open(Tempfile.new.path))
    refute File.exist?(file.path)
  end

  it "deletes IOs that respond to #path after upload" do
    io = FakeIO.new("file")
    def io.path; (@tempfile ||= Tempfile.new).path; end
    @uploader.upload(io)
    refute File.exist?(io.path)
  end

  it "doesn't raise an error if file is already deleted" do
    tempfile = Tempfile.new
    File.delete(tempfile.path)
    @uploader.upload(tempfile)
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
    @uploader.class.plugin :delete_raw, storages: [:store]
    @uploader.class.new(:cache).upload(tempfile = Tempfile.new)
    assert File.exist?(tempfile.path)
    @uploader.class.new(:store).upload(tempfile = Tempfile.new)
    refute File.exist?(tempfile.path)
  end
end
