require "test_helper"

class RenewMetadataTest < Minitest::Test
  def setup
    @attacher = attacher { plugin :renew_metadata }
  end

  test "reextracts metadata on attacher set" do
    uploaded_file = @attacher.cache.upload(fakeio("image"))
    uploaded_file.metadata["size"] = 24354535

    recached_file = @attacher.set(uploaded_file.to_json)

    assert_equal 5, recached_file.metadata["size"]
  end

  test "works with versions" do
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
