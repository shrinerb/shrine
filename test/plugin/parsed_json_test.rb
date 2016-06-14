require "test_helper"
require "shrine/plugins/parsed_json"

describe Shrine::Plugins::ParsedJson do
  before do
    @attacher = attacher { plugin :parsed_json }
  end

  it "enables assigning cached files with hashes" do
    cached_file = @attacher.cache.upload(fakeio)
    @attacher.assign(cached_file.data)
    assert @attacher.get
  end
end
