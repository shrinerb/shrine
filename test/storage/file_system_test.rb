require "test_helper"

require "uploadie/storage/file_system"
require "uploadie/storage/memory"
require "uploadie/storage"
require "uploadie/utils"

require "fileutils"

class FileSystemTest < Minitest::Test
  def file_system(*args)
    Uploadie::Storage::FileSystem.new(*args)
  end

  def root
    "tmp"
  end

  def setup
    @storage = file_system(root)
    @uploadie = Class.new(Uploadie)
    @uploadie.storages = {
      file_system: Uploadie::Storage::FileSystem.new(root),
      memory:      Uploadie::Storage::Memory.new,
    }
  end

  def teardown
    FileUtils.rm_rf(root)
  end

  test "passes the lint" do
    Uploadie::Storage::Lint.call(file_system(root))
    Uploadie::Storage::Lint.call(file_system(root, subdirectory: "uploads"))
  end

  test "creates the given directory" do
    @storage = file_system(root)
    assert File.directory?(root)

    @storage = file_system(root, subdirectory: "uploads")
    assert File.directory?("#{root}/uploads")
  end

  test "creates subdirectories when uploading files" do
    @storage.upload(fakeio, "a/a/a.jpg")

    assert @storage.exists?("a/a/a.jpg")
  end

  test "files and UploadeFiles from FileSystem are movable" do
    file                      = Uploadie::Utils.copy_to_tempfile("", image)
    file_system_uploaded_file = @uploadie.new(:file_system).upload(fakeio)
    memory_uploaded_file      = @uploadie.new(:memory).upload(fakeio)

    assert @storage.movable?(file, nil)
    assert @storage.movable?(file_system_uploaded_file, nil)
    refute @storage.movable?(memory_uploaded_file, nil)
  end

  test "moves files and uploaded files" do
    file          = Uploadie::Utils.copy_to_tempfile("", image)
    uploaded_file = @uploadie.new(:file_system).upload(fakeio)

    @storage.move(file, "foo")
    assert @storage.exists?("foo")
    refute File.exists?(file.path)

    @storage.move(uploaded_file, "bar")
    assert @storage.exists?("bar")
    refute uploaded_file.exists?
  end

  test "creates subdirectories when moving files" do
    file          = Uploadie::Utils.copy_to_tempfile("", image)
    uploaded_file = @uploadie.new(:file_system).upload(fakeio)

    @storage.move(file, "a/a/a.jpg")
    assert @storage.exists?("a/a/a.jpg")

    @storage.move(uploaded_file, "/b/b/b.jpg")
    assert @storage.exists?("b/b/b.jpg")
  end

  test "opens the file in binary mode" do
    @storage.upload(fakeio, "foo.jpg")

    assert @storage.open("foo.jpg").binmode?
  end

  test "#url returns the full path without :subdirectory" do
    @storage = file_system(root)
    @storage.upload(fakeio, "foo.jpg")

    assert_equal "tmp/foo.jpg", @storage.url("foo.jpg")
  end

  test "#url applies a host without :subdirectory" do
    @storage = file_system(root, host: "124.83.12.24")
    @storage.upload(fakeio, "foo.jpg")

    assert_equal "124.83.12.24/tmp/foo.jpg", @storage.url("foo.jpg")
  end

  test "#url returns the path relative to the :subdirectory" do
    @storage = file_system(root, subdirectory: "uploads")
    @storage.upload(fakeio, "foo.jpg")

    assert_equal "/uploads/foo.jpg", @storage.url("foo.jpg")
  end

  test "#clear! creates the directory after deleting it" do
    @storage = file_system(root)
    @storage.clear!(:confirm)

    assert File.directory?(root)
  end

  test "#clear! is able to delete old files" do
    @storage = file_system(root)
    @storage.upload(fakeio, "foo")

    @storage.clear!(older_than: Time.now - 1)
    assert @storage.exists?("foo")

    @storage.clear!(older_than: Time.now + 1)
    refute @storage.exists?("foo")
  end
end
