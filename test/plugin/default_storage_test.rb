require "test_helper"

describe "the default_storage plugin" do
  def attacher(**options)
    super() { plugin :default_storage, **options }
  end

  it "allows setting the cache as symbol" do
    @attacher = attacher(cache: :store)
    assert_equal :store, @attacher.cache.storage_key
  end

  it "allows setting the cache as a block" do
    @attacher = attacher(cache: ->(record, name) { :store })
    assert_equal :store, @attacher.cache.storage_key
  end

  it "allows setting the store as symbol" do
    @attacher = attacher(store: :cache)
    assert_equal :cache, @attacher.store.storage_key
  end

  it "allows setting the store as a block" do
    @attacher = attacher(store: ->(record, name) { :cache })
    assert_equal :cache, @attacher.store.storage_key
  end
end
