require "test_helper"

describe "the remove_invalid plugin" do
  before do
    @attacher = attacher { plugin :remove_invalid }
  end

  it "deletes and removes the invalid file" do
    @attacher.class.validate { errors << :foo }
    cached_file = @attacher.cache.upload(fakeio)
    @attacher.set(cached_file)

    refute cached_file.exists?
    assert @attacher.get.nil?
  end
end
