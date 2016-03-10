require "test_helper"
require "shrine/storage/file_system"

describe "the moving plugin" do
  before do
    @shrine = Class.new(Shrine)
    @shrine.storages = {
      file_system: Shrine::Storage::FileSystem.new("tmp"),
      memory:      Shrine::Storage::Memory.new,
    }
    @shrine.plugin :moving, storages: [:file_system, :memory]
  end

  after do
    FileUtils.rm_rf("tmp")
  end

  it "uses the storage to move the IO" do
    @uploader = @shrine.new(:file_system)
    file = Tempfile.new("")
    file.instance_eval { undef delete }
    uploaded_file = @uploader.upload(file)
    assert uploaded_file.exists?
    refute File.exist?(file.path)
  end

  it "uploads and deletes the IO if storage doesn't support moving" do
    @uploader = @shrine.new(:memory)
    uploaded_file = @uploader.upload(file = Tempfile.new(""))
    assert uploaded_file.exists?
    refute file.path
  end

  it "uploads and deletes if the IO isn't movable" do
    @uploader = @shrine.new(:file_system)
    memory_file = @shrine.new(:memory).upload(fakeio)
    uploaded_file = @uploader.upload(memory_file)
    assert uploaded_file.exists?
    refute memory_file.exists?
  end

  it "doesn't trip if IO isn't deletable" do
    @uploader = @shrine.new(:file_system)
    uploaded_file = @uploader.upload(fakeio)
    assert uploaded_file.exists?
  end

  it "only moves to specified storages" do
    @uploader = @shrine.new(:file_system)
    @uploader.opts[:move_files_to_storages] = []
    uploaded_file = @uploader.upload(file = Tempfile.new(""))
    assert File.exist?(file.path)
  end
end
