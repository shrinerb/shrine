require "test_helper"
require "shrine/plugins/remove_invalid"

describe Shrine::Plugins::RemoveInvalid do
  before do
    @attacher = attacher { plugin :remove_invalid }
  end

  it "deletes and removes invalid files" do
    @attacher.class.validate { errors << :foo }
    @attacher.set(cached_file = @attacher.cache.upload(fakeio))
    refute cached_file.exists?
    refute @attacher.get
  end

  it "doesn't remove stored files" do
    @attacher.class.validate { errors << :foo }
    @attacher.set(stored_file = @attacher.store.upload(fakeio))
    assert stored_file.exists?
    assert @attacher.get
  end
end
