require "test_helper"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.class_eval do
  self.verbose = false

  create_table :users do |t|
    t.text :avatar_data
  end
end
# Get rid of deprecation warnings.
ActiveRecord::Base.raise_in_transactional_callbacks = true

describe "the activerecord plugin" do
  before do
    @uploader = uploader { plugin :activerecord }

    user_class = Object.const_set("User", Class.new(ActiveRecord::Base))
    user_class.table_name = :users
    user_class.include @uploader.class[:avatar]

    @user = user_class.new
    @attacher = @user.avatar_attacher
  end

  after do
    Object.send(:remove_const, "User")
    ActiveRecord::Base.connection.execute "DELETE FROM users"
  end

  it "sets validation errors on the record" do
    @user.avatar_attacher.class.validate { errors << "Foo" }
    @user.avatar = fakeio

    refute @user.valid?
    assert_equal Hash[avatar: ["Foo"]], @user.errors.to_hash
  end

  it "triggers saving if file was attached" do
    @user.avatar_attacher.instance_eval do
      def save
        @save = true
      end
    end

    @user.save
    refute @user.avatar_attacher.instance_variable_get("@save")

    @user.update(avatar: fakeio)
    assert @user.avatar_attacher.instance_variable_get("@save")
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
