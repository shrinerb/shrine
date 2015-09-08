require "test_helper"

class AttachmentTest < Minitest::Test
  def setup
    @uploadie = uploader(:bare).class
    user_class = Struct.new(:avatar_data)
    user_class.include @uploadie[:avatar]
    @user = user_class.new
  end

  test "assigns the correct attacher class" do
    assert_equal @uploadie, @user.avatar_attacher.uploadie_class
  end

  test "setting and getting" do
    @user.avatar = fakeio("image")

    assert_equal "image", @user.avatar.read
  end

  test "introspection" do
    assert_match "Attachment(avatar)", @user.class.ancestors[1].to_s
    assert_match "Attachment(avatar)", @user.class.ancestors[1].inspect
  end

  test ".attachment alias" do
    @user.class.include @uploadie.attachment(:foo)
    assert_match "Attachment(foo)", @user.class.ancestors[1].to_s
  end
end
