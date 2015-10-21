require "test_helper"

describe "the storage_methods plugin" do
  before do
    @attacher = attacher { plugin :storage_methods }
    @user = @attacher.record
  end

  it "exposes attachment's cache" do
    assert_equal @user.avatar_attacher.cache, @user.avatar_cache
  end

  it "exposes attachment's store" do
    assert_equal @user.avatar_attacher.store, @user.avatar_store
  end
end
