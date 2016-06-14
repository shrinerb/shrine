require "test_helper"
require "shrine/plugins/cached_attachment_data"

describe Shrine::Plugins::CachedAttachmentData do
  before do
    @attacher = attacher { plugin :cached_attachment_data }
    @user = @attacher.record
  end

  it "returns the attachment data only if it's cached" do
    assert_equal nil, @user.cached_avatar_data
    @user.avatar = fakeio
    assert_equal @user.avatar.to_json, @user.cached_avatar_data
    @user.avatar_attacher.promote
    assert_equal nil, @user.cached_avatar_data
  end

  it "returns the attachment data only if it's changed" do
    @user.avatar_data = @attacher.cache!(fakeio).to_json
    assert_equal nil, @user.cached_avatar_data
  end
end
