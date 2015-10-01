require "test_helper"

describe "remove_attachment plugin" do
  before do
    @attacher = attacher { plugin :remove_attachment }
    @user = @attacher.record
  end

  it "nullifies files" do
    @user.avatar = fakeio
    @user.remove_avatar = true

    assert_equal nil, @user.avatar
  end

  it "doesn't nullify filese if set to false" do
    @user.avatar = fakeio
    @user.remove_avatar = "false"

    refute_equal nil, @user.avatar
  end

  it "keeps the remove value" do
    @user.remove_avatar = true
    assert_equal true, @user.remove_avatar

    @user.remove_avatar = false
    assert_equal false, @user.remove_avatar
  end
end
