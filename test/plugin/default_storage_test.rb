require "test_helper"
require "shrine/plugins/default_storage"

describe Shrine::Plugins::DefaultStorage do
  it "allows setting the cache as symbol" do
    @attacher = attacher { plugin :default_storage, cache: :store }
    assert_equal :store, @attacher.cache.storage_key
  end

  it "allows setting the cache as a block" do
    @attacher = attacher { plugin :default_storage, cache: ->(record,name){:store} }
    assert_equal :store, @attacher.cache.storage_key
  end

  it "allows setting the store as symbol" do
    @attacher = attacher { plugin :default_storage, store: :cache }
    assert_equal :cache, @attacher.store.storage_key
  end

  it "allows setting the store as a block" do
    @attacher = attacher { plugin :default_storage, store: ->(record,name){:cache} }
    assert_equal :cache, @attacher.store.storage_key
  end
end
