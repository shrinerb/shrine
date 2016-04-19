require "test_helper"

describe "the restore_cached_data plugin" do
  before do
    @attacher = attacher { plugin :restore_cached_data }
  end

  it "reextracts metadata of set cached files" do
    cached_file = @attacher.cache.upload(fakeio("image"))
    cached_file.metadata["size"] = 24354535
    @attacher.assign(cached_file.to_json)
    assert_equal 5, @attacher.get.metadata["size"]
  end

  it "skips extracting if the file is from :store" do
    stored_file = @attacher.store.upload(fakeio("image"))
    stored_file.metadata["size"] = 24354535
    Shrine.any_instance.expects(:extract_metadata).never
    @attacher.assign(stored_file.to_json)
  end

  it "checks that the file exists" do
    cached_file = @attacher.cache.upload(fakeio("image"))
    cached_file.data["id"] = "nonexistent"
    @attacher.assign(cached_file.to_json)
    refute @attacher.get
  end

  it "checks that the file exists only if it's cached" do
    stored_file = @attacher.store.upload(fakeio("image"))
    stored_file.data["id"] = "nonexistent"
    Shrine::UploadedFile.any_instance.expects(:exists?).never
    @attacher.assign(stored_file.to_json)
  end
end
