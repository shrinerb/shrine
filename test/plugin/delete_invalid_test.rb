require "test_helper"

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
end
