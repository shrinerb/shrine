require "test_helper"
require "minitest/mock"

require "uploadie/storage/file_system"
require "uploadie/utils"

require "fileutils"

class MovingTest < Minitest::Test
  def uploadie(storages)
    uploadie = Class.new(Uploadie)
    uploadie.storages = {
      file_system: Uploadie::Storage::FileSystem.new("tmp"),
      memory:      Uploadie::Storage::Memory.new,
    }
    uploadie.plugin :moving, storages: storages
    uploadie
  end

  def teardown
    FileUtils.rm_rf("tmp")
  end

  test "uses the storage to move the IO" do
    @uploader = uploadie([:file_system]).new(:file_system)
    file = Uploadie::Utils.copy_to_tempfile("", image)
    file.singleton_class.instance_eval { undef_method :delete }

    uploaded_file = @uploader.upload(file)

    assert uploaded_file.exists?
    refute File.exist?(file.path)
  end

  test "uploads and deletes the IO if storage doesn't support moving" do
    @uploader = uploadie([:memory]).new(:memory)

    file = Uploadie::Utils.copy_to_tempfile("", image); path = file.path
    stored_file = @uploader.upload(file)
    assert stored_file.exists?
    refute File.exist?(path)

    uploaded_file = @uploader.upload(fakeio)
    stored_file = @uploader.upload(uploaded_file)
    assert stored_file.exists?
    refute uploaded_file.exists?
  end

  test "doesn't trip if IO doesn't respond to delete" do
    @uploader = uploadie([:memory]).new(:memory)
    uploaded_file = @uploader.upload(fakeio)

    assert uploaded_file.exists?
  end

  test "only moves to specified storages" do
    @uploader = uploadie([:file_system]).new(:memory)
    file = Uploadie::Utils.copy_to_tempfile("", image)
    uploaded_file = @uploader.upload(file)
    assert File.exist?(file.path)

    @uploader = uploadie([:memory]).new(:file_system)
    file = Uploadie::Utils.copy_to_tempfile("", image)
    uploaded_file = @uploader.upload(file)
    assert File.exist?(file.path)
  end

  test "throws error for unexisting storage" do
    assert_raises(Uploadie::Error) { uploadie([:nonexistent]) }
  end
end
