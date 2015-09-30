require "test_helper"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.class_eval do
  self.verbose = false

  create_table :users do |t|
    t.text :avatar_data
  end
end

class ActiverecordTest < Minitest::Test
  include Minitest::Hooks

  def setup
    @uploader = uploader { plugin :activerecord }

    user_class = Class.new(ActiveRecord::Base)
    user_class.table_name = :users
    def user_class.model_name; ActiveModel::Name.new(self, nil, "User"); end
    user_class.include @uploader.class[:avatar]

    @user = user_class.new
  end

  def around
    ActiveRecord::Base.transaction do
      super
      raise ActiveRecord::Rollback
    end
  end

  test "validation" do
    @uploader.class.validate { errors << "Foo" }
    @user.avatar = fakeio

    refute @user.valid?
    assert_equal ["Foo"], @user.errors[:avatar]
  end

  test "saving" do
    @user.avatar_attacher.singleton_class.class_eval do
      def save
        @saved = true
      end
    end
    @user.save

    assert @user.avatar_attacher.instance_variable_get("@saved")
  end

  test "promoting" do
    @user.avatar = fakeio
    @user.save

    assert_equal "store", @user.avatar.storage_key
  end

  test "custom promoting" do
    @uploader.class.plugin :activerecord, promote: ->(record, name, uploaded_file) do
      record.avatar = nil
    end
    @user.avatar = fakeio
    @user.save

    assert_equal nil, @user.avatar
  end

  test "replacing" do
    @user.avatar = fakeio
    @user.save
    uploaded_file = @user.avatar

    @user.avatar = fakeio
    @user.save

    refute uploaded_file.exists?
  end

  test "replacing only happens at the very end" do
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

  test "destroying" do
    @user.avatar = fakeio
    @user.save
    uploaded_file = @user.avatar

    @user.destroy

    refute uploaded_file.exists?
  end

  test "works on form objects" do
    user_form_class = Class.new do
      attr_accessor :avatar_data

      def self.validate(&block)
        @validation = block
      end
    end

    user_form_class.include @uploader.class[:avatar]
    user_form = user_form_class.new

    user_form.avatar = fakeio

    refute_equal nil, user_form.avatar
    refute_equal nil, user_form_class.instance_variable_get('@validation')
  end
end
