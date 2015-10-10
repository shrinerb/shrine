require "test_helper"
require "mocha/mini_test"

describe "restore_metadata test" do
  before do
    @attacher = attacher { plugin :restore_metadata }
  end

  it "reextracts metadata on attacher set" do
    uploaded_file = @attacher.cache.upload(fakeio("image"))
    uploaded_file.metadata["size"] = 24354535

    restored_file = @attacher.assign(uploaded_file.to_json)

    assert_equal 5, restored_file.metadata["size"]
  end

  it "doesn't bother reextracting if the same file is already assigned" do
    uploaded_file = @attacher.assign(fakeio("image"))
    uploaded_file.metadata["size"] = 24354535
    Shrine.any_instance.expects(:extract_metadata).never

    restored_file = @attacher.assign(uploaded_file.to_json)

    assert_equal 5, restored_file.metadata["size"]
  end

  it "works with versions" do
    @attacher.shrine_class.plugin :versions, names: [:original, :thumb]

    original = @attacher.cache.upload(fakeio("original"))
    thumb = @attacher.cache.upload(fakeio("thumb"))

    original.metadata["size"] = 244356859
    thumb.metadata["size"] = 349832598345

    cached = @attacher.assign "original" => original.data, "thumb" => thumb.data

    assert_equal 8, cached[:original].metadata["size"]
    assert_equal 5, cached[:thumb].metadata["size"]
  end
end
