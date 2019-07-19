require "test_helper"

require "shrine/storage/file_system"
require "shrine/storage/linter"

require "fileutils"
require "tmpdir"

describe Shrine::Storage::FileSystem do
  def file_system(*args)
    Shrine::Storage::FileSystem.new(*args)
  end

  def root
    File.join(Dir.tmpdir, "shrine")
  end

  def root_symlink
    File.join(Dir.tmpdir, "shrine-symlink")
  end

  before do
    @storage = file_system(root)
    @shrine = Class.new(Shrine)
    @shrine.storages = {
      file_system: Shrine::Storage::FileSystem.new(root),
      memory:      Shrine::Storage::Memory.new,
    }

    File.symlink(root, root_symlink)
  end

  after do
    File.delete(root_symlink) if File.symlink?(root_symlink)
    FileUtils.rm_r(root) if File.directory?(root)
  end

  it "passes the linter" do
    Shrine::Storage::Linter.new(file_system(root)).call
    Shrine::Storage::Linter.new(file_system(root, prefix: "uploads")).call
  end

  describe "#initialize" do
    before do
      Pathname(root).rmtree
    end

    it "expands the directory" do
      assert_equal File.expand_path("test"),        file_system("test").directory.to_s
      assert_equal File.expand_path("test/prefix"), file_system("test", prefix: "prefix").directory.to_s
    end

    it "creates the given directory" do
      @storage = file_system(root)
      assert File.directory?(root)

      @storage = file_system(root, prefix: "uploads")
      assert File.directory?("#{root}/uploads")
    end

    it "sets directory permissions" do
      @storage = file_system(root, directory_permissions: 0777)
      assert_permissions 0777, root
    end

    it "doesn't change permissions of existing directories" do
      FileUtils.mkdir(root, mode: 0777)
      file_system(root)
      assert_permissions 0777, root
    end

    it "handles directory permissions being nil" do
      file_system(root, directory_permissions: nil)
    end
  end

  describe "#upload" do
    it "creates subdirectories" do
      @storage.upload(fakeio, "a/a/a.jpg")
      assert @storage.exists?("a/a/a.jpg")
    end

    it "copies full file content" do
      @storage.upload(fakeio("A" * 20_000), "foo.jpg")
      assert_equal 20_000, @storage.open("foo.jpg").size
    end

    it "sets file permissions" do
      @storage = file_system(root, permissions: 0600)
      @storage.upload(fakeio, "foo.jpg")
      assert_permissions 0600, @storage.open("foo.jpg").path
    end

    it "handles file permissions being nil" do
      @storage = file_system(root, permissions: nil)
      @storage.upload(fakeio, "foo.jpg")
    end

    it "sets directory permissions on intermediary directories" do
      @storage = file_system(root, directory_permissions: 0777)
      @storage.upload(fakeio, "a/b/c/file.jpg")
      assert_permissions 0777, "#{root}/a"
      assert_permissions 0777, "#{root}/a/b"
      assert_permissions 0777, "#{root}/a/b/c"
    end

    it "handles directory permissions being nil" do
      @storage = file_system(root, directory_permissions: nil)
      @storage.upload(fakeio, "a/b/c/file.jpg")
    end

    describe "on :move" do
      it "moves movable files" do
        file          = tempfile("file")
        uploaded_file = @shrine.new(:file_system).upload(fakeio("file"))

        @storage.upload(file,          "foo", move: true)
        @storage.upload(uploaded_file, "bar", move: true)

        assert_equal "file", @storage.open("foo").read
        assert_equal "file", @storage.open("bar").read

        refute File.exist?(file.path)
        refute uploaded_file.exists?
      end

      it "creates subdirectories" do
        file          = tempfile("file")
        uploaded_file = @shrine.new(:file_system).upload(fakeio("file"))

        @storage.upload(file, "a/a/a.jpg", move: true)
        assert @storage.exists?("a/a/a.jpg")

        @storage.upload(uploaded_file, "b/b/b.jpg", move: true)
        assert @storage.exists?("b/b/b.jpg")
      end

      it "cleans moved file's directory" do
        uploaded_file = @shrine.new(:file_system).upload(fakeio, location: "a/a/a.jpg")
        @storage.upload(uploaded_file, "b.jpg", move: true)
        refute @storage.exists?("a/a")
      end

      it "sets file permissions" do
        @storage = file_system(root, permissions: 0600)
        @storage.upload(tempfile("file"), "bar.jpg", move: true)
        assert_permissions 0600, @storage.open("bar.jpg").path
      end

      it "doesn't move unmovable files" do
        file          = fakeio("file")
        uploaded_file = @shrine.new(:memory).upload(fakeio("file"))

        @storage.upload(file,          "foo", move: true)
        @storage.upload(uploaded_file, "bar", move: true)

        assert_equal "file", @storage.open("foo").read
        assert_equal "file", @storage.open("bar").read
      end
    end

    it "ignores extra options" do
      @storage.upload(fakeio, "foo.jpg", foo: "bar")
    end
  end

  describe "#open" do
    it "opens the file in binary mode" do
      @storage.upload(fakeio, "foo.jpg")
      assert @storage.open("foo.jpg").binmode?
    end

    it "accepts additional File#open options" do
      @storage.upload(fakeio, "foo.jpg")
      @storage.open("foo.jpg", external_encoding: "utf-8")
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
    it "returns the full path without :prefix" do
      @storage = file_system(root)
      @storage.upload(fakeio, "foo.jpg")
      assert_equal "#{root}/foo.jpg", @storage.url("foo.jpg")
    end

    it "applies a host without :prefix" do
      @storage = file_system(root)
      @storage.upload(fakeio, "foo.jpg")
      assert_equal "http://124.83.12.24#{root}/foo.jpg", @storage.url("foo.jpg", host: "http://124.83.12.24")
    end

    it "returns the path relative to the :prefix" do
      @storage = file_system(root, prefix: "uploads")
      @storage.upload(fakeio, "foo.jpg")
      assert_equal "/uploads/foo.jpg", @storage.url("foo.jpg")
    end

    it "accepts a host with :prefix" do
      @storage = file_system(root, prefix: "uploads")
      @storage.upload(fakeio, "foo.jpg")
      assert_equal "http://abc123.cloudfront.net/uploads/foo.jpg", @storage.url("foo.jpg", host: "http://abc123.cloudfront.net")
    end
  end

  describe "#clear!" do
    describe "without a block" do
      it "purges the whole directory" do
        @storage.upload(fakeio, "foo")
        @storage.upload(fakeio, "bar/baz")
        @storage.clear!
        refute @storage.directory.join("foo").exist?
        refute @storage.directory.join("bar").exist?
        assert @storage.directory.directory?
      end

      it "works with symlinks" do
        @storage = file_system(root_symlink)
        @storage.upload(StringIO.new, "foo")
        @storage.upload(StringIO.new, "bar/baz")
        @storage.clear!
        refute @storage.directory.join("foo").exist?
        refute @storage.directory.join("bar").exist?
        assert @storage.directory.directory?
        assert File.symlink?(root_symlink)
      end unless RUBY_ENGINE == "jruby" # https://github.com/jruby/jruby/issues/5539
    end

    describe "with a block" do
      it "deletes selected files and directories" do
        time = Time.utc(2017, 3, 29)

        @storage.upload(fakeio, "foo")
        @storage.upload(fakeio, "dir/bar")
        @storage.upload(fakeio, "dir/baz")
        @storage.upload(fakeio, "dir/dir/quux")

        File.utime(time,     time,     @storage.directory.join("dir/bar"))
        File.utime(time - 1, time - 1, @storage.directory.join("foo"))
        File.utime(time - 1, time - 1, @storage.directory.join("dir/baz"))
        File.utime(time - 2, time - 2, @storage.directory.join("dir/dir/quux"))

        @storage.clear! { |path| path.mtime < time }

        refute @storage.directory.join("foo").exist?
        assert @storage.directory.join("dir/bar").exist?
        refute @storage.directory.join("dir/baz").exist?
        refute @storage.directory.join("dir/dir").exist?
        assert @storage.directory.directory?
      end

      it "works with symlinks" do
        time = Time.utc(2017, 3, 29)

        @storage = file_system(root_symlink)
        @storage.upload(fakeio, "foo")

        File.utime(time - 1, time - 1, @storage.directory.join("foo"))

        @storage.clear! { |path| path.mtime < time }

        refute @storage.directory.join("foo").exist?
        assert @storage.directory.directory?
        assert File.symlink?(root_symlink)
      end unless RUBY_ENGINE == "jruby" # https://github.com/jruby/jruby/issues/5539
    end
  end

  describe "#path" do
    it "returns path to the file" do
      assert_equal "#{root}/foo/bar/baz", @storage.path("foo/bar/baz").to_s
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
    @storage = file_system(root, prefix: "/uploads")
    @storage.upload(fakeio, "foo.jpg")
    assert_equal "#{root}/uploads", @storage.directory.to_s
    assert_equal "#{root}/uploads/foo.jpg", @storage.open("foo.jpg").path
  end

  def assert_permissions(expected, path)
    assert_equal expected, File.lstat(path).mode & 0777
  end
end
