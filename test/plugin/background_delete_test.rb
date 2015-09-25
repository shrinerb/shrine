require "test_helper"

class BackgroundDeleteTest < Minitest::Test
  def attacher(block)
    super() { plugin :background_delete, delete: block }
  end

  test "calls the block when replacing" do
    called = false
    @attacher = attacher ->(uploaded_file) { called = true }
    @attacher.set(fakeio)
    @attacher.set(fakeio)
    @attacher.replace

    assert called
  end

  test "calls the block when destroying" do
    called = false
    @attacher = attacher ->(uploaded_file) { called = true }
    @attacher.set(fakeio)
    @attacher.destroy

    assert called
  end
end
