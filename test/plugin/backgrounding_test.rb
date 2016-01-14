require "test_helper"
require "sequel"

db = Sequel.connect("#{"jdbc:" if RUBY_ENGINE == "jruby"}sqlite::memory:")
db.create_table :users do
  primary_key :id
  column :avatar_data, :text
end

Sequel.cache_anonymous_models = false

describe "the backgrounding plugin" do
  before do
    @uploader = uploader do
      plugin :sequel
      plugin :backgrounding
    end

    user_class = Object.const_set("User", Sequel::Model(:users))
    user_class.include @uploader.class[:avatar]

    @user = user_class.new
    @attacher = @user.avatar_attacher
  end

  after do
    User.db[:users].delete
    Object.send(:remove_const, "User")
  end

  describe "promoting" do
    it "stores the file and saves it to record" do
      @user.avatar_attacher.class.promote do |data|
        @fiber = Fiber.new { self.class.promote(data) }
      end

      @user.update(avatar: fakeio)

      assert_equal "cache", @user.reload.avatar.storage_key
      @attacher.instance_variable_get("@fiber").resume
      assert_equal "store", @user.reload.avatar.storage_key
    end

    it "doesn't get triggered when there is nothing to promote" do
      @user.avatar_attacher.class.promote do |data|
        @fiber = Fiber.new { self.class.promote(data) }
      end

      @user.save

      refute @attacher.instance_variable_defined?("@fiber")
    end

    it "doesn't get triggered again if the record is saved" do
      @user.avatar_attacher.class.promote do |data|
        @fiber = Fiber.new { self.class.promote(data) }
      end
      @user.update(avatar: fakeio)
      fiber = @attacher.instance_variable_get("@fiber")

      @user.save

      assert_equal fiber, @attacher.instance_variable_get("@fiber")
    end

    it "doesn't error when record wasn't found" do
      @user.avatar_attacher.class.promote do |data|
        @fiber = Fiber.new { self.class.promote(data) }
      end
      @user.update(avatar: fakeio)
      @user.destroy

      @attacher.instance_variable_get("@fiber").resume
    end
  end

  describe "deleting" do
    it "replaces files" do
      @user.avatar_attacher.class.delete do |data|
        @fiber = Fiber.new { self.class.delete(data) }
      end
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.update(avatar: fakeio)

      assert uploaded_file.exists?
      @user.avatar_attacher.instance_variable_get("@fiber").resume
      refute uploaded_file.exists?
    end

    it "destroys files" do
      @attacher.class.delete do |data|
        @fiber = Fiber.new { self.class.delete(data) }
      end
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.destroy

      assert uploaded_file.exists?
      @attacher.instance_variable_get("@fiber").resume
      refute uploaded_file.exists?
    end

    it "does regular deleting if nothing was assigned" do
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.destroy

      refute uploaded_file.exists?
    end
  end
end
