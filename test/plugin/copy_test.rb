require "test_helper"
require "shrine/plugins/copy"

describe Shrine::Plugins::Copy do
  before do
    @attacher = attacher { plugin :copy }
    @user = @attacher.record
  end

  describe "record copy" do
    it "duplicates the attacher and attachment" do
      @user.avatar = fakeio
      copied_user = @user.dup
      refute_equal @user.avatar_attacher, copied_user.avatar_attacher
      assert_equal copied_user, copied_user.avatar_attacher.record
      assert_instance_of @user.avatar_attacher.class, copied_user.avatar_attacher
      refute_equal nil, copied_user.avatar
      refute_equal @user.avatar, copied_user.avatar
    end

    it "keeps #initialize_copy a private method" do
      assert_includes @user.private_methods, :initialize_copy
    end
  end

  describe "attacher copy" do
    it "creates copy of a stored file" do
      @attacher.set(@attacher.store.upload(fakeio))
      copied_attacher = @user.dup.avatar_attacher
      assert copied_attacher.stored?
      refute_equal @attacher.get, copied_attacher.get

      uploaded_file = copied_attacher.get
      copied_attacher.finalize
      assert_equal uploaded_file, copied_attacher.get
    end

    it "creates copy of a cached file" do
      @attacher.set(@attacher.cache.upload(fakeio))
      copied_attacher = @user.dup.avatar_attacher
      assert copied_attacher.cached?
      refute_equal @attacher.get, copied_attacher.get

      copied_attacher.finalize
      assert copied_attacher.stored?
    end

    it "doesn't do anything when no attachment is assigned" do
      copied_attacher = @user.dup.avatar_attacher
      assert_equal nil, copied_attacher.get
    end

    it "works correctly with moving plugin" do
      @attacher.shrine_class.plugin :moving
      @attacher.set(@attacher.cache.upload(fakeio))
      @attacher.record.dup
      assert @attacher.get.exists?
    end
  end
end
