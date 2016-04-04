require "test_helper"

describe "the delete_promoted plugin" do
  before do
    @attacher = attacher { plugin :delete_promoted }
  end

  it "deletes the promoted file" do
    @attacher.assign(fakeio)
    promoted = @attacher.get
    @attacher.promote(@attacher.get)
    refute promoted.exists?
  end

  it "returns the result of promoting" do
    @attacher.assign(fakeio)
    result = @attacher.promote(@attacher.get)
    assert_equal @attacher.get, result
  end
end
