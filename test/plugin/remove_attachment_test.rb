require "test_helper"

class RemoveAttachmentTest < Minitest::Test
  def setup
    @attacher = attacher { plugin :remove_attachment }
  end

  test "removing files" do
    @attacher.set(fakeio)
    @attacher.remove = true

    assert_equal nil, @attacher.get
  end

  test "not removing files" do
    @attacher.set(fakeio)
    @attacher.remove = "false"

    refute_equal nil, @attacher.get
  end

  test "reading the remove state" do
    assert_equal nil, @attacher.remove

    @attacher.remove = true

    assert_equal true, @attacher.remove
  end

  test "attachment interface" do
    @user = @attacher.record
    @user.avatar = fakeio
    @user.remove_avatar = true

    assert_equal nil, @user.avatar
    assert_equal true, @user.remove_avatar
  end
end
