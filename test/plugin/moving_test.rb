require "test_helper"
require "shrine/storage/file_system"
require "down"

describe "moving plugin" do
  def shrine(storages)
    shrine = Class.new(Shrine)
    shrine.storages = {
      file_system: Shrine::Storage::FileSystem.new("tmp"),
      memory:      Shrine::Storage::Memory.new,
    }
    shrine.plugin :moving, storages: storages
    shrine
  end

  after do
    FileUtils.rm_rf("tmp")
  end

  it "uses the storage to move the IO" do
    @uploader = shrine([:file_system]).new(:file_system)
    file = Down.copy_to_tempfile("", image)
    file.singleton_class.instance_eval { undef_method :delete }

    uploaded_file = @uploader.upload(file)

    assert uploaded_file.exists?
    refute File.exist?(file.path)
  end

  it "uploads and deletes the IO if storage doesn't support moving" do
    @uploader = shrine([:memory]).new(:memory)

    file = Down.copy_to_tempfile("", image); path = file.path
    stored_file = @uploader.upload(file)
    assert stored_file.exists?
    refute File.exist?(path)

    uploaded_file = @uploader.upload(fakeio)
    stored_file = @uploader.upload(uploaded_file)
    assert stored_file.exists?
    refute uploaded_file.exists?
  end

  it "doesn't trip if IO doesn't respond to delete" do
    @uploader = shrine([:memory]).new(:memory)
    uploaded_file = @uploader.upload(fakeio)

    assert uploaded_file.exists?
  end

  it "only moves to specified storages" do
    @uploader = shrine([:file_system]).new(:memory)
    file = Down.copy_to_tempfile("", image)
    uploaded_file = @uploader.upload(file)
    assert File.exist?(file.path)

    @uploader = shrine([:memory]).new(:file_system)
    file = Down.copy_to_tempfile("", image)
    uploaded_file = @uploader.upload(file)
    assert File.exist?(file.path)
  end
end
