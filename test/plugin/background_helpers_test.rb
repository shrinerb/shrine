require "test_helper"
require "sequel"

db = Sequel.connect("#{"jdbc:" if RUBY_ENGINE == "jruby"}sqlite::memory:")
db.create_table :users do
  primary_key :id
  column :avatar_data, :text
end

Sequel.cache_anonymous_models = false

describe "the background_helpers plugin" do
  before do
    @uploader = uploader do
      plugin :sequel
      plugin :background_helpers
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
      @attacher.assign(fakeio)
      @user.save

      assert_equal "cache", @user.reload.avatar.storage_key
      @attacher.instance_variable_get("@fiber").resume
      assert_equal "store", @user.reload.avatar.storage_key
    end

    it "doesn't get triggered when there is nothing to promote" do
      @user.avatar_attacher.class.promote do |data|
        @fiber = Fiber.new { self.class.promote(data) }
      end
      @attacher._promote

      refute @attacher.instance_variable_defined?("@fiber")
    end
  end

  describe "deleting" do
    it "replaces files" do
      @user.avatar_attacher.class.delete do |data|
        @fiber = Fiber.new { self.class.delete(data) }
      end
      uploaded_file = @attacher.assign(fakeio)
      @attacher.assign(fakeio)
      @attacher.replace

      assert uploaded_file.exists?
      @user.avatar_attacher.instance_variable_get("@fiber").resume
      refute uploaded_file.exists?
    end

    it "destroys files" do
      @attacher.class.delete do |data|
        @fiber = Fiber.new { self.class.delete(data) }
      end
      uploaded_file = @attacher.assign(fakeio)
      @attacher.destroy

      assert uploaded_file.exists?
      @attacher.instance_variable_get("@fiber").resume
      refute uploaded_file.exists?
    end
  end
end
