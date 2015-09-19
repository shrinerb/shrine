require "test_helper"

require "shrine/storage/file_system"
require "shrine/storage/memory"
require "shrine/storage"
require "shrine/utils"

require "fileutils"

class FileSystemTest < Minitest::Test
  def file_system(*args)
    Shrine::Storage::FileSystem.new(*args)
  end

  def root
    "tmp"
  end

  def setup
    @storage = file_system(root)
    @shrine = Class.new(Shrine)
    @shrine.storages = {
      "file_system" => Shrine::Storage::FileSystem.new(root),
      "memory"      => Shrine::Storage::Memory.new,
    }
  end

  def teardown
    FileUtils.rm_rf(root)
  end

  test "passes the lint" do
    Shrine::Storage::Lint.call(file_system(root))
    Shrine::Storage::Lint.call(file_system(root, subdirectory: "uploads"))
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
    file                      = Shrine::Utils.copy_to_tempfile("", image)
    file_system_uploaded_file = @shrine.new(:file_system).upload(fakeio)
    memory_uploaded_file      = @shrine.new(:memory).upload(fakeio)

    assert @storage.movable?(file, nil)
    assert @storage.movable?(file_system_uploaded_file, nil)
    refute @storage.movable?(memory_uploaded_file, nil)
  end

  test "moves files and uploaded files" do
    file          = Shrine::Utils.copy_to_tempfile("", image)
    uploaded_file = @shrine.new(:file_system).upload(fakeio)

    @storage.move(file, "foo")
    assert @storage.exists?("foo")
    refute File.exists?(file.path)

    @storage.move(uploaded_file, "bar")
    assert @storage.exists?("bar")
    refute uploaded_file.exists?
  end

  test "creates subdirectories when moving files" do
    file          = Shrine::Utils.copy_to_tempfile("", image)
    uploaded_file = @shrine.new(:file_system).upload(fakeio)

    @storage.move(file, "a/a/a.jpg")
    assert @storage.exists?("a/a/a.jpg")

    @storage.move(uploaded_file, "/b/b/b.jpg")
    assert @storage.exists?("b/b/b.jpg")
  end

  test "opens the file in binary mode" do
    @storage.upload(fakeio, "foo.jpg")

    assert @storage.open("foo.jpg").binmode?
  end

  test "delete cleans subdirectories, unless :clean is false" do
    @storage.upload(fakeio, "a/a/a.jpg")
    @storage.delete("a/a/a.jpg")

    refute File.exist?(@storage.path("a"))
    assert File.exist?(@storage.directory)

    @storage = file_system(root, clean: false)
    @storage.upload(fakeio, "a/a/a.jpg")
    @storage.delete("a/a/a.jpg")

    assert File.exist?(@storage.path("a"))
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

  test "sets directory permissions" do
    @storage = file_system(root, permissions: 0755)
    assert_permissions 0755, root

    @storage.clear!(:confirm)
    assert_permissions 0755, root
  end

  test "sets file permissions" do
    @storage = file_system(root, permissions: 0755)
    @storage.upload(fakeio, "foo.jpg")

    assert_permissions 0755, @storage.path("foo.jpg")

    @storage = file_system(root, permissions: 0755)
    file = Shrine::Utils.copy_to_tempfile("", image)
    @storage.move(file, "bar.jpg")

    assert_permissions 0755, @storage.path("bar.jpg")
  end

  def assert_permissions(expected, path)
    assert_equal expected, File.lstat(path).mode & 0777
  end
end
