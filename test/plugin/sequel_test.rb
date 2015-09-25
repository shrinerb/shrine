require "test_helper"
require "sequel"

DB = Sequel.sqlite
DB.create_table :users do
  primary_key :id
  String :avatar_data
end

Sequel.cache_anonymous_models = false

class SequelTest < Minitest::Test
  include Minitest::Hooks

  def setup
    @uploader = uploader { plugin :sequel }

    user_class = Sequel::Model(:users)
    user_class.include @uploader.class[:avatar]

    @user = user_class.new
  end

  test "validation" do
    @uploader.class.validate { errors << :foo }
    @user.avatar = fakeio

    refute @user.valid?
    assert_equal Hash[avatar: [:foo]], @user.errors
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
    @uploader.class.plugin :sequel, promote: ->(record, name, uploaded_file) do
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

    @user.class.class_eval do
      def before_save
        raise
        super
      end
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
end
