require "test_helper"
require "sequel"

DB = Sequel.sqlite
DB.create_table :users do
  primary_key :id
  column :avatar_data, :text
end

Sequel.cache_anonymous_models = false

describe "sequel plugin" do
  before do
    @uploader = uploader { plugin :sequel }

    user_class = Sequel::Model(:users)
    user_class.include @uploader.class[:avatar]

    @user = user_class.new
  end

  after { DB[:users].delete }

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

  it "works with background promoting" do
    @uploader.class.plugin :background_helpers
    @user.avatar_attacher.class.promote do |cached_file|
      @fiber = Fiber.new { promote(cached_file); record.save }
    end
    @user.avatar = fakeio
    @user.save

    assert_equal "cache", @user.reload.avatar.storage_key
    @user.avatar_attacher.instance_variable_get("@fiber").resume
    assert_equal "store", @user.reload.avatar.storage_key
  end

  it "bails on promoting if the record attachment" do
    @uploader.class.plugin :background_helpers
    @user.avatar_attacher.class.promote do |cached_file|
      @fiber = Fiber.new { promote(cached_file); record.save }
    end
    @user.avatar = fakeio
    @user.save
    @user.class.dataset.update(avatar_data: nil)

    assert_equal nil, @user.class.first.avatar
    @user.avatar_attacher.instance_variable_get("@fiber").resume
    assert_equal nil, @user.class.first.avatar
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
