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

  it "accepts custom promoting" do
    @uploader.class.plugin :sequel, promote: ->(cached_file, record:, name:) do
      @fiber = Fiber.new { record.send("#{name}_attacher").promote(cached_file) }
    end
    @user.avatar = fakeio
    @user.save

    assert_equal "cache", @user.avatar.storage_key
    @fiber.resume
    assert_equal "store", @user.avatar.storage_key
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
