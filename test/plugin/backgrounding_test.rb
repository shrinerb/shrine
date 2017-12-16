require "test_helper"
require "shrine/plugins/backgrounding"
require "sequel"

db = Sequel.connect("#{"jdbc:" if RUBY_ENGINE == "jruby"}sqlite::memory:")
db.create_table :users do
  primary_key :id
  column :avatar_data, :text
end

Sequel::Model.cache_anonymous_models = false

describe Shrine::Plugins::Backgrounding do
  before do
    @uploader = uploader do
      plugin :sequel
      plugin :backgrounding
    end

    user_class = Object.const_set("User", Sequel::Model(:users))
    user_class.include @uploader.class::Attachment.new(:avatar)

    @user = user_class.new
    @attacher = @user.avatar_attacher
  end

  after do
    User.dataset.delete if User < Sequel::Model
    Object.send(:remove_const, "User")
  end

  describe "promoting" do
    it "stores the file and saves it to record" do
      @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
      @user.update(avatar: fakeio)
      assert_equal "cache", @user.reload.avatar.storage_key
      @attacher.instance_variable_get("@f").resume
      assert_equal "store", @user.reload.avatar.storage_key
    end

    it "passes the correct :action" do
      @attacher.class.promote { |data| self.class.promote(data) }
      @user.avatar = fakeio
      Shrine::Attacher.any_instance.expects(:promote).with(@user.avatar, {action: :store})
      @user.save

      @attacher.class.promote { |data| self.class.promote(data.merge("action" => "foo")) }
      @user.avatar = fakeio
      Shrine::Attacher.any_instance.expects(:promote).with(@user.avatar, {action: :foo})
      @user.save
    end

    it "returns the attacher" do
      @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
      @user.update(avatar: fakeio)
      assert_instance_of @attacher.class, @attacher.instance_variable_get("@f").resume
    end

    it "doesn't get triggered when there is nothing to promote" do
      @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
      @user.save
      refute @attacher.instance_variable_defined?("@f")
    end

    it "doesn't error when record was deleted before promoting" do
      @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
      @user.update(avatar: fakeio)
      @user.destroy
      @attacher.instance_variable_get("@f").resume
    end

    it "doesn't error when record was deleted during promoting" do
      @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
      @attacher.class.class_eval do
        def swap(*)
          record.this.delete
          super
        end
      end
      @user.update(avatar: fakeio)
      @attacher.instance_variable_get("@f").resume
    end

    it "doesn't continue uploading if attachment has already changed" do
      @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
      @user.update(avatar: fakeio)
      @user.this.update(avatar_data: nil)
      Shrine.any_instance.expects(:upload).never
      refute @attacher.instance_variable_get("@f").resume
      assert @user.reload.avatar.nil?
    end

    it "aborts promoting if attachment has changed during" do
      @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
      @attacher.class.class_eval do
        def swap(*)
          record.this.update(avatar_data: nil)
          super
        end
      end
      @user.update(avatar: fakeio)
      refute @attacher.instance_variable_get("@f").resume
      assert @user.reload.avatar.nil?
    end

    it "doesn't return the record if promoting aborted" do
      @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
      @attacher.class.class_eval { def swap(*); nil; end }
      @user.update(avatar: fakeio)
      refute @attacher.instance_variable_get("@f").resume
    end

    it "respects default storage set via Attachment.new" do
      @uploader.class.storages[:other] = Shrine::Storage::Test.new
      @user.class.include @uploader.class::Attachment.new(:avatar, store: :other)
      @attacher.class.promote { |data| self.class.promote(data) }
      @user.update(avatar: fakeio)
      assert_equal "other", @user.reload.avatar.storage_key
    end
  end

  describe "deleting" do
    it "is triggered on destroy" do
      @attacher.class.delete { |data| @f = Fiber.new{self.class.delete(data)} }
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.destroy
      assert uploaded_file.exists?
      @attacher.instance_variable_get("@f").resume
      refute uploaded_file.exists?
    end

    it "is triggered on replace" do
      @attacher.class.delete { |data| @f = Fiber.new{self.class.delete(data)} }
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.update(avatar: fakeio)
      assert uploaded_file.exists?
      @attacher.instance_variable_get("@f").resume
      refute uploaded_file.exists?
    end

    it "returns the attacher" do
      @attacher.class.delete { |data| @f = Fiber.new{self.class.delete(data)} }
      @user.update(avatar: fakeio)
      @user.destroy
      assert_instance_of @attacher.class, @attacher.instance_variable_get("@f").resume
    end

    it "does regular deleting if nothing was assigned" do
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.destroy
      refute uploaded_file.exists?
    end
  end

  describe ".dump" do
    it "creates a serializable hash of the attacher" do
      @attacher.record.save
      @attacher.assign(fakeio)
      data = @attacher.class.dump(@attacher)
      assert_equal @attacher.get, @attacher.uploaded_file(data["attachment"])
      assert_equal [@attacher.record.class.to_s, @attacher.record.id.to_s], data["record"]
      assert_equal @attacher.name.to_s, data["name"]
    end

    it "handles the case when attachment is nil" do
      data = @attacher.class.dump(@attacher)
      assert_nil data["attachment"]
    end

    it "includes the shrine_class" do
      Object.const_set(:MyUploader, @attacher.shrine_class)
      data = @attacher.class.dump(@attacher)
      assert_equal "MyUploader", data["shrine_class"]
      Object.send(:remove_const, :MyUploader)
    end

    it "sets shrine_class to nil for anonymous classes" do
      data = @attacher.class.dump(@attacher)
      assert_nil data["shrine_class"]
    end
  end

  describe ".load" do
    it "instantiates the attacher" do
      @attacher.record.save
      data = @attacher.class.dump(@attacher)
      attacher = @attacher.class.load(data)
      assert_instance_of @attacher.class, attacher
      assert_equal @attacher.name, attacher.name
      assert_equal @attacher.record.class, attacher.record.class
      assert_equal @attacher.record.id, attacher.record.id
    end

    it "handles record not found" do
      @attacher.record.save
      @attacher.record.destroy
      data = @attacher.class.dump(@attacher)
      attacher = @attacher.class.load(data)
      assert_equal @attacher.record.class, attacher.record.class
      assert_equal @attacher.record.id.to_s, attacher.record.id
    end

    it "loads attacher from shrine_class if available" do
      Object.const_set(:MyUploader, @attacher.shrine_class)
      data = @attacher.class.dump(@attacher)
      User.class_eval { undef avatar_attacher }
      attacher = @attacher.class.load(data)
      Object.send(:remove_const, :MyUploader)
    end
  end

  it "works with PORO models" do
    promote_job = proc do |data|
      attacher = @attacher.class.promote(data)
      assert_equal @attacher.record.class, attacher.record.class
      assert attacher.stored?
      assert attacher.get.exists?
    end

    delete_job = proc do |data|
      attacher = @attacher.class.delete(data)
      assert_equal @attacher.record.class, attacher.record.class
      assert_instance_of @attacher.record.class, attacher.record.class
      refute attacher.get.exists?
    end

    @attacher = attacher { plugin :backgrounding }
    @attacher.class.promote { |data| promote_job.call(data) }
    @attacher.class.delete { |data| delete_job.call(data) }

    @attacher.assign(fakeio)
    @attacher.finalize
  end
end
