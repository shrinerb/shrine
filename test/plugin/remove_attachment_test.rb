require "test_helper"

class RemoveAttachmentTest < Minitest::Test
  def setup
    @uploader = uploader(:remove_attachment)
    @user = Struct.new(:avatar_data).new
    @user.class.include @uploader.class[:avatar]
    @attacher = @user.avatar_attacher
  end

  test "removing files" do
    @user.avatar = fakeio
    @user.remove_avatar = true

    assert_equal nil, @user.avatar
  end

  test "not removing files" do
    @user.avatar = fakeio
    @user.remove_avatar = "false"

    refute_equal nil, @user.avatar
  end

  test "reading the remove state" do
    assert_equal nil, @user.remove_avatar

    @user.remove_avatar = true

    assert_equal true, @user.remove_avatar
  end
end
