require "test_helper"
require "shrine/storage/linter"

describe Shrine::Storage::Linter do
  before do
    @storage = Shrine::Storage::Test.new
    @linter = Shrine::Storage::Linter.new(@storage)
  end

  it "passes for memory storage" do
    @linter.call
  end

  describe "upload" do
    it "tests that storage allows 3rd options argument" do
      @storage.instance_eval { def upload(io, id); super; end }
      assert_raises(ArgumentError) { @linter.call }
    end

    it "takes into account that storage can modify location" do
      @storage.instance_eval { def upload(io, id, *); id.replace("bar"); super; end }
      @linter.call
    end
  end

  describe "open" do
    it "tests that returned object is an IO" do
      @storage.instance_eval { def open(id); StringIO.new("foo").tap { |io| io.instance_eval{undef rewind} }; end }
      assert_raises(Shrine::LintError) { @linter.call }
    end

    it "tests that returned IO is not empty" do
      @storage.instance_eval { def open(id); StringIO.new; end }
      assert_raises(Shrine::LintError) { @linter.call }
    end
  end

  describe "exists" do
    it "tests that it returns true for uploaded files" do
      @storage.instance_eval { def exists?(id); false; end }
      assert_raises(Shrine::LintError) { @linter.call }
    end
  end

  describe "url" do
    it "tests that it's defined" do
      @storage.instance_eval { def url(id); end }
      @linter.call
    end

    it "tests that it returns either nil or a string" do
      @storage.instance_eval { def url(id); :symbol; end }
      assert_raises(Shrine::LintError) { @linter.call }
    end
  end

  describe "delete" do
    it "tests that file doesn't exist anymore" do
      @storage.instance_eval { def delete(id); end }
      assert_raises(Shrine::LintError) { @linter.call }
    end

    it "tests that deleting nonexisting file shouldn't fail" do
      @storage.instance_eval { def delete(id); raise unless store.key?(id); end }
      assert_raises(Shrine::LintError) { @linter.call }
    end
  end

  describe "move" do
    it "tests that storage allows 3rd options argument" do
      @storage.instance_eval { def move(io, id); super; end }
      assert_raises(ArgumentError) { @linter.call }
    end

    it "tests that #movable? is defined" do
      @storage.instance_eval { undef movable? }
      assert_raises(NoMethodError) { @linter.call }
    end

    it "tests that destination exists" do
      @storage.instance_eval { def move(io, id, *); store.delete(io.id); end }
      assert_raises(Shrine::LintError) { @linter.call }
    end

    it "tests that source doesn't exist" do
      @storage.instance_eval { def move(io, id, *); store[id] = io.read; end }
      assert_raises(Shrine::LintError) { @linter.call }
    end

    it "isn't tested if storage doesn't define it" do
      @storage.instance_eval { undef move }
      @linter.call
    end
  end

  it "doesn't leave any files" do
    @linter.call
    assert_empty @storage.store
  end

  describe "clear!" do
    it "tests that files don't exist after clearing" do
      @storage.instance_eval { def clear!; end }
      assert_raises(Shrine::LintError) { @linter.call }
    end

    it "doesn't require #clear! to be defined" do
      @storage.instance_eval { undef clear! }
      @linter.call
    end
  end

  describe "#presign" do
    before do
      @storage.instance_eval { def presign(id, **options); { method: "post", url: "foo" }; end }
    end

    it "passes for correct implementation" do
      @linter.call
    end

    it "tests that result is a Hash" do
      @storage.instance_eval { def presign(id, **options); Object.new; end }
      assert_raises(Shrine::LintError) { @linter.call }
    end

    it "passes for result that responds to #to_h" do
      @storage.instance_eval { def presign(id, **options); Struct.new(:method, :url).new("post", "foo"); end }
      @linter.call
    end

    it "tests that Hash includes :url key" do
      @storage.instance_eval { def presign(id, **options); { method: "post" }; end }
      assert_raises(Shrine::LintError) { @linter.call }

      @storage.instance_eval { def presign(id, **options); Struct.new(:method).new("post"); end }
      assert_raises(Shrine::LintError) { @linter.call }
    end

    it "tests that Hash includes :method key" do
      @storage.instance_eval { def presign(id, **options); { url: "foo" }; end }
      assert_raises(Shrine::LintError) { @linter.call }

      @storage.instance_eval { def presign(id, **options); Struct.new(:url).new("foo"); end }
      assert_raises(Shrine::LintError) { @linter.call }
    end

    it "tests that method accepts options" do
      @storage.instance_eval { def presign(id); { method: "post", url: "foo" }; end }
      assert_raises(ArgumentError) { @linter.call }
    end
  end

  it "can print errors as warnings" do
    @storage.instance_eval { def exists?(id); true; end }
    linter = Shrine::Storage::Linter.new(@storage, action: :warn)
    assert_output(nil, /file still #exists\?/) { linter.call }
  end

  it "accepts an IO factory" do
    @linter.call(->{StringIO.new("file")})
  end

  it "works for storages that close files on upload" do
    @storage.instance_eval { def upload(io, id, *); super; io.close; end }
    @linter.call
  end

  it "accounts for storages which cannot write immediately to previously used location" do
    @storage.instance_eval do
      def upload(io, id, *)
        @uploaded ||= []
        raise if @uploaded.include?(id)
        super
        @uploaded << id
      end
    end

    @linter.call
  end

  it "accounts for storages processing uploaded files" do
    @storage.instance_eval { def upload(io, id, *); store[id] = "processed"; end }
    @linter.call
  end

  it "doesn't pass any file extensions" do
    @storage.instance_eval { def upload(io, id, *); raise if id.include?("."); super; end }
    @linter.call
  end
end
