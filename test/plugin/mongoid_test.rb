require "mongoid"
require "test_helper"

Mongoid.load!(File.expand_path("../../support/mongoid.yml", __FILE__), :test)
Moped.logger.level = ::Logger::INFO

MODEL_DEF = <<-EOS
  include Mongoid::Document

  store_in collection: "users"

  field :avatar_data, type: String
EOS


describe "the mongoid plugin" do
  before do
    Shrine.storages = {
      cache: fakeio,
      store: fakeio
    }

    @uploader = uploader { plugin :mongoid }

    user_class = Shrine.const_set("User", Class.new { eval MODEL_DEF })
    user_class.include @uploader.class[:avatar]

    @user = user_class.new
    @attacher = @user.avatar_attacher
  end

  after do
    Shrine.send(:remove_const, "User")
    Mongoid::Sessions.default[:users].drop()
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
    assert @user.avatar.exists?
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
