require "test_helper"
require "uploadie/storage/file_system"
require "uploadie/storage"
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

  test "uploads files to nonexisting subdirectories" do
    @storage.upload(fakeio, "foo/bar/baz.jpg")

    assert @storage.exists?("foo/bar/baz.jpg")
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
