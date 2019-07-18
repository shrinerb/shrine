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

  it "skips extracting if the file is not cached" do
    stored_file = @attacher.store!(fakeio)
    @attacher.cache.expects(:extract_metadata).never
    @attacher.assign(stored_file.to_json)
  end

  it "forwards the context" do
    cached_file = @attacher.cache!(fakeio)
    @attacher.shrine_class.plugin :add_metadata
    @attacher.shrine_class.add_metadata(:context) { |io, context| context.keys.sort.to_s }
    @attacher.assign(cached_file.to_json)
    assert_equal "[:metadata, :name, :record]", @attacher.get.metadata["context"]
  end
end
