require "test_helper"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Migration.class_eval do
  create_table :users do |t|
    t.text :avatar_data
  end
end
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
    @user.class.delete_all
    Object.send(:remove_const, "User")
  end

  it "promotes on save" do
    @user.update(avatar: fakeio("file1")) # insert
    refute @user.changed?
    assert_equal "store", @user.avatar.storage_key
    assert_equal "file1", @user.avatar.read

    @user.update(avatar: fakeio("file2")) # update
    refute @user.changed?
    assert_equal "store", @user.avatar.storage_key
    assert_equal "file2", @user.avatar.read
  end

  it "adds validation errors to the record" do
    @user.avatar_attacher.class.validate { errors << "error" }
    @user.avatar = fakeio
    refute @user.valid?
    assert_equal Hash[avatar: ["error"]], @user.errors.to_hash
  end

  it "replaces after saving" do
    @user.update(avatar: fakeio)
    uploaded_file = @user.avatar
    @user.update(avatar: fakeio)
    refute uploaded_file.exists?
  end

  it "doesn't replace if callback chain halted" do
    @user.update(avatar: fakeio)
    uploaded_file = @user.avatar
    @user.class.before_save { false }
    @user.update(avatar: fakeio)
    assert uploaded_file.exists?
  end

  it "triggers saving if file was attached" do
    @user.avatar_attacher.expects(:save).twice
    @user.update(avatar: fakeio) # insert
    @user.update(avatar: fakeio) # update
  end

  it "doesn't trigger saving if file wasn't attached" do
    @user.avatar_attacher.expects(:save).never
    @user.save # insert
    @user.save # update
  end

  it "destroys attachments" do
    @user.update(avatar: fakeio)
    @user.destroy
    refute @user.avatar.exists?
  end

  it "works with backgrounding plugin" do
    @uploader.class.plugin :backgrounding
    @attacher.class.promote { |data| self.class.promote(data) }
    @attacher.class.delete { |data| self.class.delete(data) }

    @user.update(avatar: fakeio)
    assert_equal "store", @user.reload.avatar.storage_key

    @user.destroy
    refute @user.avatar.exists?
  end

  it "doesn't raise errors in background job when record is not found" do
    @uploader.class.plugin :backgrounding
    @attacher.class.promote { |data| record.delete; self.class.promote(data) }
    @attacher.class.delete { |data| record.delete; self.class.delete(data) }
    @user.update(avatar: fakeio)
    @user.destroy
  end

  it "doesn't send another background job when saved again" do
    @uploader.class.plugin :backgrounding
    @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
    @user.update(avatar: fakeio)
    fiber = @user.avatar_attacher.instance_variable_get("@f")
    @user.save
    assert_equal fiber, @user.avatar_attacher.instance_variable_get("@f")
  end

  it "terminates swapping if attachment has changed" do
    @attacher.instance_eval do
      def swap(uploaded_file)
        record.class.update_all(avatar_data: nil)
        super
      end
    end
    @user.update(avatar: fakeio)
    assert_equal nil, @user.reload.avatar

    @attacher.instance_eval do
      def swap(uploaded_file)
        record.class.delete_all
        super
      end
    end
    @user.update(avatar: fakeio)
  end
end
