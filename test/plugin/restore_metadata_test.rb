require "test_helper"

describe "restore_metadata test" do
  before do
    @attacher = attacher { plugin :restore_metadata }
  end

  it "reextracts metadata on attacher set" do
    uploaded_file = @attacher.cache.upload(fakeio("image"))
    uploaded_file.metadata["size"] = 24354535

    recached_file = @attacher.set(uploaded_file.to_json)

    assert_equal 5, recached_file.metadata["size"]
  end

  it "works with versions" do
    @attacher.shrine_class.plugin :versions, names: [:original, :thumb]

    original = @attacher.cache.upload(fakeio("original"))
    thumb = @attacher.cache.upload(fakeio("thumb"))

    original.metadata["size"] = 244356859
    thumb.metadata["size"] = 349832598345

    cached = @attacher.set "original" => original.data, "thumb" => thumb.data

    assert_equal 8, cached[:original].metadata["size"]
    assert_equal 5, cached[:thumb].metadata["size"]
  end
end
