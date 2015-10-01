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

  around do |&block|
    DB.transaction(rollback: :always) { super(&block) }
  end

  it "sets validation errors on the record" do
    @uploader.class.validate { errors << "Foo" }
    @user.avatar = fakeio

    refute @user.valid?
    assert_equal ["Foo"], @user.errors[:avatar]
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
    @uploader.class.plugin :sequel, promote: ->(record, name, uploaded_file) do
      record.avatar = nil
    end
    @user.avatar = fakeio
    @user.save

    assert_equal nil, @user.avatar
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
