require "test_helper"

describe Shrine::Attachment do
  before do
    @uploader = uploader.class
    user_class = Struct.new(:avatar_data)
    user_class.include @uploader[:avatar]
    @user = user_class.new
  end

  describe "<name>_attacher" do
    it "is assigned a correct attacher class" do
      assert_equal @uploader, @user.avatar_attacher.shrine_class
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
      @user.avatar_attacher.cache.storage.instance_eval do
        def url(id, **options)
          options.to_json
        end
      end
      @user.avatar = fakeio

      assert_equal '{"foo":"bar"}', @user.avatar_url(foo: "bar")
    end
  end

  it "is inheritable" do
    admin_class = Class.new(@user.class)
    admin = admin_class.new

    admin.avatar = fakeio("image")

    assert_equal "image", admin.avatar.read
  end

  it "is introspectable" do
    assert_match "Attachment(avatar)", @user.class.ancestors[1].inspect
  end
end
