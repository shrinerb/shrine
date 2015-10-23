require "test_helper"

require "shrine/storage/file_system"
require "shrine/storage/linter"

require "down"
require "fileutils"

describe Shrine::Storage::FileSystem do
  def file_system(*args)
    Shrine::Storage::FileSystem.new(*args)
  end

  def root
    "tmp"
  end

  before do
    @storage = file_system(root)
    @shrine = Class.new(Shrine)
    @shrine.storages = {
      file_system: Shrine::Storage::FileSystem.new(root),
      memory:      Shrine::Storage::Memory.new,
    }
  end

  after do
    FileUtils.rm_rf(root)
  end

  it "passes the linter" do
    Shrine::Storage::Linter.call(file_system(root))
    Shrine::Storage::Linter.call(file_system(root, subdirectory: "uploads"))
  end

  describe "#initialize" do
    it "creates the given directory" do
      @storage = file_system(root)
      assert File.directory?(root)

      @storage = file_system(root, subdirectory: "uploads")
      assert File.directory?("#{root}/uploads")
    end

    it "sets directory permissions" do
      @storage = file_system(root, permissions: 0755)
      assert_permissions 0755, root
    end
  end

  describe "#upload" do
    it "creates subdirectories" do
      @storage.upload(fakeio, "a/a/a.jpg")

      assert @storage.exists?("a/a/a.jpg")
    end

    it "rewinds the input file" do
      @storage.upload(input = fakeio("image"), "foo.jpg")

      assert_equal "image", input.read
    end

    it "sets file permissions" do
      @storage = file_system(root, permissions: 0755)
      @storage.upload(fakeio, "foo.jpg")

      assert_permissions 0755, @storage.open("foo.jpg").path
    end
  end

  describe "#movable?" do
    it "returns true for files and UploadedFiles from FileSystem" do
      file                      = Down.copy_to_tempfile("", image)
      file_system_uploaded_file = @shrine.new(:file_system).upload(fakeio)
      memory_uploaded_file      = @shrine.new(:memory).upload(fakeio)

      assert @storage.movable?(file, nil)
      assert @storage.movable?(file_system_uploaded_file, nil)
      refute @storage.movable?(memory_uploaded_file, nil)
    end
  end

  describe "#move" do
    it "moves files and UploadedFiles" do
      file          = Down.copy_to_tempfile("", image)
      uploaded_file = @shrine.new(:file_system).upload(fakeio)

      @storage.move(file, "foo")
      assert @storage.exists?("foo")
      refute File.exists?(file.path)

      @storage.move(uploaded_file, "bar")
      assert @storage.exists?("bar")
      refute uploaded_file.exists?
    end

    it "creates subdirectories" do
      file          = Down.copy_to_tempfile("", image)
      uploaded_file = @shrine.new(:file_system).upload(fakeio)

      @storage.move(file, "a/a/a.jpg")
      assert @storage.exists?("a/a/a.jpg")

      @storage.move(uploaded_file, "b/b/b.jpg")
      assert @storage.exists?("b/b/b.jpg")
    end

    it "cleans moved file's directory" do
      uploaded_file = @shrine.new(:file_system).upload(fakeio, location: "a/a/a.jpg")

      @storage.move(uploaded_file, "b.jpg")
      refute @storage.exists?("a/a")
    end

    it "sets file permissions" do
      @storage = file_system(root, permissions: 0755)
      file = Down.copy_to_tempfile("", image)
      @storage.move(file, "bar.jpg")

      assert_permissions 0755, @storage.open("bar.jpg").path
    end
  end

  describe "#open" do
    it "opens the file in binary mode" do
      @storage.upload(fakeio, "foo.jpg")

      assert @storage.open("foo.jpg").binmode?
    end
  end

  describe "#delete" do
    it "cleans subdirectories" do
      @storage.upload(fakeio, "a/a/a.jpg")
      @storage.delete("a/a/a.jpg")

      refute @storage.exists?("a/a")
    end
  end

  describe "#url" do
    it "returns the full path without :subdirectory" do
      @storage = file_system(root)
      @storage.upload(fakeio, "foo.jpg")

      assert_equal "tmp/foo.jpg", @storage.url("foo.jpg")
    end

    it "applies a host without :subdirectory" do
      @storage = file_system(root, host: "124.83.12.24")
      @storage.upload(fakeio, "foo.jpg")

      assert_equal "124.83.12.24/tmp/foo.jpg", @storage.url("foo.jpg")
    end

    it "returns the path relative to the :subdirectory" do
      @storage = file_system(root, subdirectory: "uploads")
      @storage.upload(fakeio, "foo.jpg")

      assert_equal "/uploads/foo.jpg", @storage.url("foo.jpg")
    end
  end

  describe "#clear!" do
    it "creates the directory after deleting it" do
      @storage = file_system(root)
      @storage.clear!(:confirm)

      assert File.directory?(root)
    end

    it "is able to delete old files" do
      @storage = file_system(root)
      @storage.upload(fakeio, "foo")

      @storage.clear!(older_than: Time.now - 1)
      assert @storage.exists?("foo")

      @storage.clear!(older_than: Time.now + 1)
      refute @storage.exists?("foo")
    end

    it "reestablishes directory permissions" do
      @storage.clear!(:confirm)
      assert_permissions 0755, root
    end
  end

  describe "#clean" do
    it "deletes empty directories up the hierarchy" do
      @storage.upload(fakeio, "a/a/a/a.jpg")
      @storage.delete("a/a/a/a.jpg")

      refute @storage.exists?("a")
      assert File.exist?(@storage.directory)

      @storage.upload(fakeio, "a/a/a/a.jpg")
      @storage.upload(fakeio, "a/b.jpg")
      @storage.delete("a/a/a/a.jpg")

      refute @storage.exists?("a/a")
      assert @storage.exists?("a")
    end
  end

  it "accepts absolute pathnames" do
    @storage = file_system(root, subdirectory: "/uploads")
    @storage.upload(fakeio, "/foo.jpg")

    assert_equal "tmp/uploads", @storage.directory.to_s
    assert_equal "tmp/uploads/foo.jpg", @storage.open("/foo.jpg").path
  end

  def assert_permissions(expected, path)
    assert_equal expected, File.lstat(path).mode & 0777
  end
end
