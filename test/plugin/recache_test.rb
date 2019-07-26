require "test_helper"
require "shrine/plugins/recache"

describe Shrine::Plugins::Recache do
  before do
    @attacher = attacher { plugin :recache }
  end

  it "recaches cached files" do
    file = @attacher.assign(fakeio("original"))

    @attacher.save

    assert_equal :cache,     @attacher.file.storage_key
    refute_equal file,       @attacher.file
    assert_equal "original", @attacher.file.read
  end

  it "doesn't recache if attachment is missing" do
    @attacher.save
  end

  it "recaches only cached files" do
    file = @attacher.attach(fakeio)

    @attacher.save

    assert_equal file, @attacher.file
  end
end
