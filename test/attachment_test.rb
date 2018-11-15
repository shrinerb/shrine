require "test_helper"

describe Shrine::Attachment do
  before do
    @attacher   = attacher
    @user       = @attacher.record
    @attachment = @user.class.ancestors.grep(Shrine::Attachment).first
  end

  describe "<name>_attacher" do
    it "is instantiated with a correct attacher class" do
      assert_equal @attacher.shrine_class::Attacher, @user.avatar_attacher.class
    end

    it "returns the same attacher instance on subsequent calls" do
      assert_equal @user.avatar_attacher, @user.avatar_attacher
    end

    it "forwards attachment options to the attacher" do
      @user = attacher(attachment_options: { store: :cache, cache: :store }).record
      assert_equal :cache, @user.avatar_attacher.store.storage_key
      assert_equal :store, @user.avatar_attacher.cache.storage_key
    end

    it "accepts additional attacher options" do
      @user.avatar_attacher(cache: :store)
      assert_equal :store, @user.avatar_attacher.cache.storage_key
      @user.avatar_attacher(store: :cache)
      assert_equal :cache, @user.avatar_attacher.store.storage_key
    end

    it "allows the user to reset the Attacher instance" do
      previous_attacher = @user.avatar_attacher
      @user.instance_variable_set(:@avatar_attacher, nil)
      refute_equal previous_attacher, @user.avatar_attacher
    end

    it "is owned by the Attachment instance" do
      assert_equal @attachment, @user.method(:avatar_attacher).owner
    end
  end

  describe "<name>=" do
    it "sets the file" do
      @user.avatar = fakeio("image")
      assert_equal "image", @user.avatar.read
    end

    it "is owned by the Attachment instance" do
      assert_equal @attachment, @user.method(:avatar=).owner
    end
  end

  describe "<name>" do
    it "gets the file" do
      assert_nil @user.avatar
      @user.avatar = fakeio("image")
      assert_equal "image", @user.avatar.read
    end

    it "is owned by the Attachment instance" do
      assert_equal @attachment, @user.method(:avatar).owner
    end
  end

  describe "<name>_url" do
    it "returns the URL of the file" do
      assert_nil @user.avatar_url
      @user.avatar = fakeio("image")
      refute_empty @user.avatar_url
    end

    it "forwards options to the attacher" do
      @user.avatar_attacher.cache.storage.instance_eval { def url(id, **o); o.to_json; end }
      @user.avatar = fakeio
      assert_equal '{"foo":"bar"}', @user.avatar_url(foo: "bar")
    end

    it "is owned by the Attachment instance" do
      assert_equal @attachment, @user.method(:avatar_url).owner
    end
  end

  it "inherits the attacher class" do
    admin_class = Class.new(@user.class)
    admin = admin_class.new
    assert_equal @user.avatar_attacher.class, admin.avatar_attacher.class
    admin.avatar = fakeio("image")
    assert_equal "image", admin.avatar.read
  end

  describe "#to_s" do
    it "is pretty" do
      assert_match "Attachment(avatar)", @user.class.ancestors[1].to_s
    end
  end

  describe "#inspect" do
    it "is pretty" do
      assert_match "Attachment(avatar)", @user.class.ancestors[1].inspect
    end
  end
end
