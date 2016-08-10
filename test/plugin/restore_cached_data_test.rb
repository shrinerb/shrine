require "test_helper"
require "shrine/plugins/restore_cached_data"

describe Shrine::Plugins::RestoreCachedData do
  before do
    @attacher = attacher { plugin :restore_cached_data }
  end

  it "reextracts metadata of set cached files" do
    cached_file = @attacher.cache!(fakeio("a" * 1024))
    cached_file.metadata["size"] = 5
    @attacher.assign(cached_file.to_json)
    assert_equal 1024, @attacher.get.metadata["size"]
  end

  it "keeps any custom metadata" do
    cached_file = @attacher.cache!(fakeio("image"))
    cached_file.metadata["custom"] = "custom"
    @attacher.assign(cached_file.to_json)
    assert_equal "custom", @attacher.get.metadata["custom"]
  end

  it "skips extracting if the file is not cached" do
    stored_file = @attacher.store!(fakeio("image"))
    @attacher.cache.expects(:extract_metadata).never
    @attacher.assign(stored_file.to_json)
  end
end
