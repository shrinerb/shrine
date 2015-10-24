require "test_helper"
require "sequel"

db = Sequel.connect("#{"jdbc:" if RUBY_ENGINE == "jruby"}sqlite::memory:")
db.create_table :users do
  primary_key :id
  column :avatar_data, :text
end

Sequel.cache_anonymous_models = false

describe "the sequel plugin" do
  before do
    @uploader = uploader { plugin :sequel }

    user_class = Object.const_set("User", Sequel::Model(:users))
    user_class.include @uploader.class[:avatar]

    @user = user_class.new
    @attacher = @user.avatar_attacher
  end

  after do
    User.db[:users].delete
    Object.send(:remove_const, "User")
  end

  it "sets validation errors on the record" do
    @user.avatar_attacher.class.validate { errors << "Foo" }
    @user.avatar = fakeio

    refute @user.valid?
    assert_equal Hash[avatar: ["Foo"]], @user.errors
  end

  it "triggers save functionality" do
    @user.avatar_attacher.singleton_class.class_eval do
      def save
        @saved = true
      end
    end
    @user.save

    assert @user.avatar_attacher.instance_variable_get("@saved")
  end

  it "promotes on save" do
    @user.avatar = fakeio
    @user.save

    assert_equal "store", @user.avatar.storage_key
  end

  it "works with background_helpers plugin" do
    @uploader.class.plugin :background_helpers
    @attacher.class.promote { |data| self.class.promote(data) }
    @attacher.class.delete { |data| self.class.delete(data) }

    @user.update(avatar: fakeio)
    assert_equal "store", @user.reload.avatar.storage_key

    @user.destroy
    refute @user.avatar.exists?
  end

  it "replaces after saving" do
    @user.avatar = fakeio
    @user.save
    uploaded_file = @user.avatar

    @user.avatar = fakeio
    @user.save

    refute uploaded_file.exists?
  end

  it "doesn't replace if there were errors during saving" do
    @user.avatar = fakeio
    @user.save
    uploaded_file = @user.avatar

    @user.class.class_eval do
      def before_save
        super
        raise
      end
    end

    @user.avatar = fakeio
    @user.save rescue nil

    assert uploaded_file.exists?
  end

  it "destroys attachments" do
    @user.avatar = fakeio
    @user.save
    uploaded_file = @user.avatar

    @user.destroy

    refute uploaded_file.exists?
  end
end
