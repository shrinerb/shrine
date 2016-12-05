require "test_helper"
require "shrine/plugins/remove_attachment"

describe Shrine::Plugins::RemoveAttachment do
  before do
    @attacher = attacher { plugin :remove_attachment }
    @user = @attacher.record
  end

  it "nullifies files" do
    @user.avatar = fakeio
    @user.remove_avatar = true
    assert_nil @user.avatar
  end

  it "doesn't nullify files if set to false" do
    @user.avatar = fakeio
    @user.remove_avatar = "false"
    refute_equal nil, @user.avatar
  end

  it "doesn't nullify files if set to 0" do
    @user.avatar = fakeio
    @user.remove_avatar = "0"
    refute_equal nil, @user.avatar
  end

  it "keeps the remove value" do
    @user.remove_avatar = true
    assert_equal true, @user.remove_avatar

    @user.remove_avatar = false
    assert_equal false, @user.remove_avatar
  end
end
