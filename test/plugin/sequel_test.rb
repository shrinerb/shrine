require "test_helper"
require "sequel"
require "sequel/extensions/pg_json"

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
    User.dataset.delete
    Object.send(:remove_const, "User")
  end

  it "promotes on save" do
    @user.update(avatar: fakeio("file1")) # insert
    refute @user.modified?
    assert_equal "store", @user.avatar.storage_key
    assert_equal "file1", @user.avatar.read

    @user.update(avatar: fakeio("file2")) # update
    refute @user.modified?
    assert_equal "store", @user.avatar.storage_key
    assert_equal "file2", @user.avatar.read
  end

  it "successfully promotes when record is invalid" do
    @user.instance_eval { def validate; errors.add(:base, "Invalid"); end }
    @user.avatar = fakeio
    @user.save(validate: false)
    assert_empty @user.changed_columns
    assert_equal "store", @user.avatar.storage_key
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
    @user.instance_eval { def before_save; cancel_action; end }
    @user.update(avatar: fakeio) rescue nil
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
    @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
    @attacher.class.delete { |data| @f = Fiber.new{self.class.delete(data)} }

    @user.update(avatar: fakeio)
    @user.delete
    @user.avatar_attacher.instance_variable_get("@f").resume
    @user = @user.class.new

    @user.update(avatar_data: @user.avatar_attacher.store.upload(fakeio).to_json)
    @user.destroy
    @user.avatar_attacher.instance_variable_get("@f").resume
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
        record.this.update(avatar_data: nil)
        super
      end
    end
    @user.update(avatar: fakeio)
    assert_equal nil, @user.reload.avatar

    @attacher.instance_eval do
      def swap(uploaded_file)
        record.this.delete
        super
      end
    end
    @user.update(avatar: fakeio)
  end

  it "adds support for Postgres JSON columns" do
    @user.class.plugin :serialization, [
      ->(value) { value },
      ->(value) { Sequel::Postgres::JSONBHash.new(JSON.parse(value)) }
    ], :avatar_data

    @user.update(avatar: fakeio)
  end
end
