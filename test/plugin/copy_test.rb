require "test_helper"
require "shrine/plugins/copy"

describe Shrine::Plugins::Copy do
  before do
    @attacher = attacher { plugin :copy }
    @user = @attacher.record
  end

  describe "record copy" do
    it "duplicates the attacher" do
      user = @user.dup
      refute_equal @user.avatar_attacher, user.avatar_attacher
      assert_equal user, user.avatar_attacher.record
      assert_instance_of @user.avatar_attacher.class, user.avatar_attacher
    end

    it "duplicates the attacher even if it wasn't instantiated" do
      assert_kind_of Shrine::Attacher, @user.dup.avatar_attacher
    end

    it "keeps #initialize_copy a private method" do
      refute @user.respond_to?(:initialize_copy)
    end

    it "doesn't error if attachment module isn't included" do
      @user.class.class_eval { undef avatar_attacher }
      @user.dup
    end
  end

  describe "attacher copy" do
    it "creates copy of a stored file" do
      @attacher.set(@attacher.store.upload(fakeio))
      attacher = @user.dup.avatar_attacher
      assert attacher.stored?
      refute_equal @attacher.get, attacher.get

      uploaded_file = attacher.get
      attacher.finalize
      assert_equal uploaded_file, attacher.get
    end

    it "creates copy of a cached file" do
      @attacher.set(@attacher.cache.upload(fakeio))
      attacher = @user.dup.avatar_attacher
      assert attacher.cached?
      refute_equal @attacher.get, attacher.get

      attacher.finalize
      assert attacher.stored?
    end

    it "works correctly with moving plugin" do
      @attacher.shrine_class.plugin :moving
      @attacher.set(@attacher.cache.upload(fakeio))
      @attacher.record.dup
      assert @attacher.get.exists?
    end
  end
end
