require "test_helper"

describe Shrine::Attachment do
  before do
    @user = attacher.record
  end

  describe "<name>_attacher" do
    it "is instantiated with a correct attacher class" do
      refute_equal Shrine, @user.avatar_attacher.shrine_class
    end
  end

  describe "<name>=" do
    it "sets the file" do
      @user.avatar = fakeio("image")
      assert_equal "image", @user.avatar.read
    end
  end

  describe "<name>" do
    it "gets the file" do
      assert_equal nil, @user.avatar
      @user.avatar = fakeio("image")
      assert_equal "image", @user.avatar.read
    end
  end

  describe "<name>_url" do
    it "returns the URL of the file" do
      assert_equal nil, @user.avatar_url
      @user.avatar = fakeio("image")
      refute_empty @user.avatar_url
    end

    it "forwards options to the attacher" do
      @user.avatar_attacher.cache.storage.instance_eval { def url(id, **o); o.to_json; end }
      @user.avatar = fakeio
      assert_equal '{"foo":"bar"}', @user.avatar_url(foo: "bar")
    end
  end

  it "inherits the attacher class" do
    admin_class = Class.new(@user.class)
    admin = admin_class.new
    assert_equal @user.avatar_attacher.class, admin.avatar_attacher.class
    admin.avatar = fakeio("image")
    assert_equal "image", admin.avatar.read
  end

  describe "#inspect" do
    it "is pretty" do
      assert_match "Attachment(avatar)", @user.class.ancestors[1].inspect
    end
  end
end
