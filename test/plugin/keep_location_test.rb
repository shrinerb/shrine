require "test_helper"

describe "the keep_location plugin" do
  before do
    uploader_class = uploader { plugin :keep_location, :cache => :store }.class
    @cache = uploader_class.new(:cache)
    @store = uploader_class.new(:store)
  end

  it "keeps the location for the specified storage" do
    cached_file = @cache.upload(fakeio)
    stored_file = @store.upload(cached_file)

    assert_equal cached_file.id, stored_file.id
  end

  it "doesn't keep the location for unspecified storage" do
    cached_file = @cache.upload(fakeio)
    recached_file = @cache.upload(cached_file)

    refute_equal cached_file.id, recached_file.id

    stored_file = @store.upload(fakeio)
    restored_file = @store.upload(stored_file)

    refute_equal stored_file.id, restored_file.id
  end

  it "still uses :location if provided" do
    cached_file = @cache.upload(fakeio)
    stored_file = @store.upload(cached_file, location: "foo")

    assert_equal "foo", stored_file.id
  end

  it "accepts an array of values" do
    @cache.class.plugin :keep_location, :store => [:store]

    stored_file = @store.upload(fakeio)
    restored_file = @store.upload(stored_file)

    assert_equal stored_file.id, restored_file.id
  end

  it "appends storages when loaded multiple times" do
    @cache.class.plugin :keep_location, :cache => :cache

    assert_equal Hash[:cache => [:store, :cache]], @cache.opts[:keep_location_mappings]
  end
end
