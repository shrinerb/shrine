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

    it "backfills size metadata if missing" do
      io = fakeio("content")
      io.instance_eval { undef size }
      uploaded_file = @shrine.new(:file_system).upload(io)
      assert_equal 7, uploaded_file.metadata["size"]

      io = fakeio("content")
      io.instance_eval { def size; 3; end }
      uploaded_file = @shrine.new(:file_system).upload(io)
      assert_equal 3, uploaded_file.metadata["size"]
    end
  end

  describe "#movable?" do
    it "returns true for files and UploadedFiles from FileSystem" do
      file                      = Tempfile.new
      file_system_uploaded_file = @shrine.new(:file_system).upload(fakeio)
      memory_uploaded_file      = @shrine.new(:memory).upload(fakeio)
      assert @storage.movable?(file, nil)
      assert @storage.movable?(file_system_uploaded_file, nil)
      refute @storage.movable?(memory_uploaded_file, nil)
    end
  end

  describe "#move" do
    it "moves files and UploadedFiles" do
      file          = Tempfile.new
      uploaded_file = @shrine.new(:file_system).upload(fakeio)

      @storage.move(file, "foo")
      assert @storage.exists?("foo")
      refute File.exist?(file.path)

      @storage.move(uploaded_file, "bar")
      assert @storage.exists?("bar")
      refute uploaded_file.exists?
    end

    it "creates subdirectories" do
      file          = Tempfile.new
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
      @storage = file_system(root, permissions: 0600)
      @storage.move(Tempfile.new, "bar.jpg")
      assert_permissions 0600, @storage.open("bar.jpg").path
    end

    it "handles file permissions being nil" do
      @storage = file_system(root, permissions: nil)
      @storage.move(Tempfile.new, "bar.jpg")
    end

    it "sets directory permissions on intermediary directories" do
      @storage = file_system(root, directory_permissions: 0777)
      @storage.move(Tempfile.new, "a/b/c/file.jpg")
      assert_permissions 0777, "#{root}/a"
      assert_permissions 0777, "#{root}/a/b"
      assert_permissions 0777, "#{root}/a/b/c"
    end

    it "handles directory permissions being nil" do
      @storage = file_system(root, directory_permissions: nil)
      @storage.move(Tempfile.new, "a/b/c/file.jpg")
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
    describe "without arguments" do
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

    describe "with :older_than" do
      it "deletes files and directories older than specified time" do
        time = Time.utc(2017, 3, 29)

        @storage.upload(fakeio, "foo")
        @storage.upload(fakeio, "dir/bar")
        @storage.upload(fakeio, "dir/baz")
        @storage.upload(fakeio, "dir/dir/quux")

        File.utime(time,     time,     @storage.directory.join("dir/bar"))
        File.utime(time - 1, time - 1, @storage.directory.join("foo"))
        File.utime(time - 1, time - 1, @storage.directory.join("dir/baz"))
        File.utime(time - 2, time - 2, @storage.directory.join("dir/dir/quux"))

        @storage.clear!(older_than: time)

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

        @storage.clear!(older_than: time)

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

  describe "#method_missing" do
    deprecated "implements #download" do
      @storage.upload(fakeio("content"), "foo.jpg")
      tempfile = @storage.download("foo.jpg")
      assert_instance_of Tempfile, tempfile
      assert_equal ".jpg", File.extname(tempfile.path)
      assert_equal "content", tempfile.read
    end

    deprecated "#download deletes the Tempfile if an error occurs while retrieving file contents" do
      tempfile = Tempfile.new
      Tempfile.stubs(:new).returns(tempfile)
      assert_raises(Errno::ENOENT) { @storage.download("foo") }
      assert tempfile.closed?
      assert_nil tempfile.path
    end

    deprecated "#download propagates failures in creating tempfiles" do
      Tempfile.stubs(:new).raises(Errno::EMFILE) # too many open files
      @storage.upload(fakeio, "foo")
      assert_raises(Errno::EMFILE) { @storage.download("foo") }
    end

    it "calls super for other methods" do
      assert_raises(NoMethodError) { @storage.foo }
    end
  end

  def assert_permissions(expected, path)
    assert_equal expected, File.lstat(path).mode & 0777
  end
end
