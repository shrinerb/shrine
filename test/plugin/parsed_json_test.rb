require "test_helper"
require "shrine/plugins/parsed_json"

describe Shrine::Plugins::ParsedJson do
  before do
    @attacher = attacher { plugin :parsed_json }
  end

  it "enables assigning cached files with hashes with string keys" do
    cached_file = @attacher.cache!(fakeio)
    @attacher.assign(cached_file.data)
    assert @attacher.get
  end

  it "enables assigning cached files with hashes with symbol keys" do
    cached_file = @attacher.cache!(fakeio)
    data = {
      id:      cached_file.data["id"],
      storage: cached_file.data["storage"]
    }
    @attacher.assign(data)
    assert @attacher.get
  end
end
