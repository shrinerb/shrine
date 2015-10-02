require "test_helper"

describe "background_delete plugin" do
  def attacher(&block)
    super() { plugin :background_delete, &block }
  end

  it "calls the block when replacing" do
    called = false
    @attacher = attacher { |uploaded_file, context| called = true }
    @attacher.set(fakeio)
    @attacher.set(fakeio)
    @attacher.replace

    assert called
  end

  it "calls the block when destroying" do
    called = false
    @attacher = attacher { |uploaded_file, context| called = true }
    @attacher.set(fakeio)
    @attacher.destroy

    assert called
  end
end
