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

  after { ActiveRecord::Base.connection.execute "DELETE FROM users" }

  it "sets validation errors on the record" do
    @user.avatar_attacher.class.validate { errors << "Foo" }
    @user.avatar = fakeio

    refute @user.valid?
    assert_equal Hash[avatar: ["Foo"]], @user.errors.to_hash
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
    @user.class.update_all(avatar_data: nil)

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
