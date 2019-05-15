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

  it "accepts options" do
    cached_file = @attacher.cache!(fakeio, metadata: { "foo" => "foo" })
    assert_equal "foo", cached_file.metadata["foo"]
    @attacher.assign(cached_file.data, foo: "bar")
    assert_equal cached_file, @attacher.get
  end
end
