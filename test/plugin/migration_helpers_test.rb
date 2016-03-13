require "test_helper"

describe "the migration_helpers plugin" do
  before do
    @attacher = attacher { plugin :migration_helpers }
    @user = @attacher.record
  end

  describe "<attachment>_cache" do
    it "exposes attachment's cache" do
      assert_equal @user.avatar_attacher.cache, @user.avatar_cache
    end
  end

  describe "<attachment>_store" do
    it "exposes attachment's store" do
      assert_equal @user.avatar_attacher.store, @user.avatar_store
    end
  end

  describe "<attachment>_cached?" do
    it "returns true if attachment is present and is cached" do
      @user.avatar_data = @user.avatar_cache.upload(fakeio).to_json
      assert @user.avatar_cached?
      @user.avatar_data = @user.avatar_store.upload(fakeio).to_json
      refute @user.avatar_cached?
      @user.avatar_data = nil
      refute @user.avatar_cached?
    end
  end

  describe "<attachment>_stored?" do
    it "returns true if attachment is present and is stored" do
      @user.avatar_data = @user.avatar_store.upload(fakeio).to_json
      assert @user.avatar_stored?
      @user.avatar_data = @user.avatar_cache.upload(fakeio).to_json
      refute @user.avatar_stored?
      @user.avatar_data = nil
      refute @user.avatar_stored?
    end
  end

  describe "update_<attachment>" do
    it "updates the attachment" do
      @attacher.set(@attacher.store.upload(fakeio("original")))
      @user.update_avatar do |avatar|
        assert_equal @user.avatar, avatar
        @user.avatar_store.upload(fakeio("replaced"))
      end
      assert_equal "replaced", @user.avatar.read
    end

    it "doesn't update attachment when current one is cached" do
      @attacher.assign(fakeio("original"))
      @user.update_avatar { fail }
    end

    it "doesn't update attachment when current one is nil" do
      @user.update_avatar { fail }
    end
  end

  it "doesn't delegate if :delegate is set to false" do
    @attacher = attacher { plugin :migration_helpers, delegate: false }
    @user = @attacher.record

    refute_respond_to @user, :avatar_cache
    refute_respond_to @user, :avatar_store
    refute_respond_to @user, :avatar_cached?
    refute_respond_to @user, :avatar_stored?
    refute_respond_to @user, :update_avatar
  end
end
