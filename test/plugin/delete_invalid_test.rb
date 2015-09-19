require "test_helper"

class DeleteInvalidTest < Minitest::Test
  def setup
    @attacher = attacher { plugin :delete_invalid }
  end

  test "it deletes the cached file if it was invalid" do
    @attacher.set(fakeio)
    assert @attacher.get.exists?

    @attacher.shrine_class.validate { errors << :foo }
    @attacher.set(fakeio)
    refute @attacher.get.exists?
  end

  test "it deletes the cached file if validation errors are raised" do
    @attacher.shrine_class.validate { errors << :foo; raise }
    @attacher.set(fakeio) rescue nil

    refute @attacher.get.exists?
  end
end
