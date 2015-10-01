require "test_helper"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.class_eval do
  self.verbose = false

  create_table :users do |t|
    t.text :avatar_data
  end
end

describe "activerecord plugin" do
  before do
    @uploader = uploader { plugin :activerecord }

    user_class = Class.new(ActiveRecord::Base)
    user_class.table_name = :users
    def user_class.model_name; ActiveModel::Name.new(self, nil, "User"); end
    user_class.include @uploader.class[:avatar]

    @user = user_class.new
  end

  around do |&block|
    ActiveRecord::Base.transaction do
      super(&block)
      raise ActiveRecord::Rollback
    end
  end

  it "sets validation errors on the record" do
    @uploader.class.validate { errors << "Foo" }
    @user.avatar = fakeio

    refute @user.valid?
    assert_equal ["Foo"], @user.errors[:avatar]
  end

  it "triggers save functionality" do
    @user.avatar_attacher.instance_eval do
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
    @uploader.class.plugin :activerecord, promote: ->(record, name, uploaded_file) do
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

    @user.class.before_save do
      raise
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
