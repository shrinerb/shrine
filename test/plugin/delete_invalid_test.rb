require "test_helper"
require "mocha/mini_test"

describe "the delete_invalid plugin" do
  def setup
    @attacher = attacher { plugin :delete_invalid }
  end

  it "deletes the cached file if it was invalid" do
    @attacher.assign(fakeio)
    assert @attacher.get.exists?

    @attacher.class.validate { errors << :foo }
    @attacher.assign(fakeio)
    refute @attacher.get.exists?
  end

  it "deletes the cached file if validation errors are raised" do
    @attacher.class.validate { errors << :foo; raise }
    @attacher.assign(fakeio) rescue nil

    refute @attacher.get.exists?
  end

  it "doesn't attempt to delete if there is no file" do
    @attacher.class.validate { errors << :foo }
    @attacher.assign(nil)
  end

  it "doesn't delete the same file twice" do
    @attacher.class.validate { errors << :foo }
    @attacher.cache.storage.expects(:delete).once

    @attacher.assign(fakeio)
    assert_kind_of Shrine::UploadedFile, @attacher.get
    @attacher.set(@attacher.get)
  end
end
