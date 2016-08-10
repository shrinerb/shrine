require "test_helper"
require "shrine/plugins/copy"

describe Shrine::Plugins::Copy do
  before do
    @attacher = attacher { plugin :copy }
    @user = @attacher.record
  end

  describe "record copy" do
    before do
      @user.avatar_data = @attacher.store!(fakeio).to_json
      @duplicated_user = @user.dup
    end

    it "duplicates the attacher" do
      refute_equal @user.avatar_attacher, @duplicated_user.avatar_attacher
      assert_equal @duplicated_user, @duplicated_user.avatar_attacher.record
      assert_instance_of @user.avatar_attacher.class, @duplicated_user.avatar_attacher
    end

    it "duplicates the attachment" do
      refute_equal nil, @duplicated_user.avatar
      refute_equal @user.avatar, @duplicated_user.avatar
    end

    it "doesn't replace original attachment on finalization" do
      @duplicated_user.avatar_attacher.finalize
      assert @user.avatar.exists?
    end

    it "keeps #initialize_copy a private method" do
      assert_includes @user.private_methods, :initialize_copy
    end
  end

  describe "attacher copy" do
    before do
      @duplicated_attacher = @user.dup.avatar_attacher
    end

    it "copies stored file to store" do
      @attacher.set(@attacher.store!(fakeio))
      @duplicated_attacher.copy(@attacher)
      assert @duplicated_attacher.stored?
      refute_equal @attacher.get, @duplicated_attacher.get
    end

    it "copies cached file to cache" do
      @attacher.set(@attacher.cache!(fakeio))
      @duplicated_attacher.copy(@attacher)
      assert @duplicated_attacher.cached?
      refute_equal @attacher.get, @duplicated_attacher.get
    end

    it "copies blank file" do
      @duplicated_attacher.set(@duplicated_attacher.store!(fakeio))
      @duplicated_attacher.copy(@attacher)
      assert_equal nil, @duplicated_attacher.get
    end

    it "deletes the current attachment" do
      @duplicated_attacher.set(original_attachment = @duplicated_attacher.store!(fakeio))
      @attacher.set(@attacher.store!(fakeio))
      @duplicated_attacher.copy(@attacher)
      @duplicated_attacher.finalize
      refute original_attachment.exists?
    end

    it "doesn't do anything when no attachment is assigned" do
      duplicated_attacher = @user.dup.avatar_attacher
      assert_equal nil, duplicated_attacher.get
    end

    it "works correctly with moving plugin" do
      @attacher.shrine_class.plugin :moving
      @attacher.set(@attacher.cache!(fakeio))
      @duplicated_attacher.copy(@attacher)
      assert @attacher.get.exists?
    end
  end
end
