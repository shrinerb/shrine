require "test_helper"

describe "the recache plugin" do
  def setup
    @attacher = attacher { plugin :recache }
  end

  it "recaches cached files" do
    @attacher.assign(fakeio("original"))
    cached_file = @attacher.get
    @attacher.save
    refute_equal cached_file, @attacher.get
  end

  it "doesn't recache if attachment is missing" do
    @attacher.save
  end

  it "recaches only cached files" do
    @attacher.set(@attacher.store.upload(fakeio))
    stored_file = @attacher.get
    @attacher.save
    assert_equal stored_file, @attacher.get
  end
end
