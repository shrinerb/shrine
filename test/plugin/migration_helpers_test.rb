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

  describe "update_<attachment>" do
    it "updates the attachment" do
      @attacher.assign(fakeio("original"))
      @attacher._promote

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

    it "doesn't update attachment when current one has changed" do
      @attacher.assign(fakeio("original"))
      @attacher._promote

      @user.update_avatar do
        @attacher.assign(fakeio("new"))
        @attacher._promote

        @user.avatar_store.upload(fakeio("replaced"))
      end

      assert_equal "new", @user.avatar.read
    end
  end
end
