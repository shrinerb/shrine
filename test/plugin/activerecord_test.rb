require "test_helper"
require "shrine/plugins/activerecord"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.connection.create_table(:users) { |t| t.text :avatar_data }
ActiveRecord::Base.raise_in_transactional_callbacks = true

describe Shrine::Plugins::Activerecord do
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

  describe "validating" do
    it "adds errors to the record" do
      @user.avatar_attacher.class.validate { errors << "error" }
      @user.avatar = fakeio
      refute @user.valid?
      assert_equal Hash[avatar: ["error"]], @user.errors.to_hash
    end
  end

  describe "promoting" do
    it "is triggered on save" do
      @user.update(avatar: fakeio("file1")) # insert
      refute @user.changed?
      assert_equal "store", @user.avatar.storage_key
      assert_equal "file1", @user.avatar.read

      @user.update(avatar: fakeio("file2")) # update
      refute @user.changed?
      assert_equal "store", @user.avatar.storage_key
      assert_equal "file2", @user.avatar.read
    end

    it "triggers callbacks" do
      @user.class.before_save do
        @promote_callback = true if avatar.storage_key == "store"
      end
      @user.update(avatar: fakeio)
      assert @user.instance_variable_get("@promote_callback")
    end

    it "bypasses validations" do
      @user.class.validate { errors.add(:base, "Invalid") }
      @user.avatar = fakeio
      @user.save(validate: false)
      refute @user.changed?
      assert_equal "store", @user.avatar.storage_key
    end

    it "works with backgrounding" do
      @uploader.class.plugin :backgrounding
      @attacher.class.promote { |data| self.class.promote(data) }
      @user.update(avatar: fakeio)
      assert_equal "store", @user.reload.avatar.storage_key
    end

    it "is terminated when attachment changed before update" do
      @attacher.instance_eval do
        def swap(*)
          record.class.update_all(avatar_data: nil)
          super
        end
      end
      @user.update(avatar: fakeio)
      assert_equal nil, @user.reload.avatar
    end

    it "is terminated when record was deleted before update" do
      @attacher.instance_eval do
        def swap(*)
          record.class.delete_all
          super
        end
      end
      @user.update(avatar: fakeio)
    end

    it "is terminated when record was deleted during update" do
      @user.instance_eval do
        def save(*)
          if avatar && avatar.storage_key == "store"
            self.class.delete_all
          end
          super
        end
      end
      @user.update(avatar: fakeio)
    end
  end

  describe "replacing" do
    it "is triggered after saving" do
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.update(avatar: fakeio)
      refute uploaded_file.exists?
    end

    it "isn't triggered when callback chain is halted" do
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.class.before_save { false }
      @user.update(avatar: fakeio)
      assert uploaded_file.exists?
    end
  end

  describe "saving" do
    it "is triggered when file is attached" do
      @user.avatar_attacher.expects(:save).twice
      @user.update(avatar: fakeio) # insert
      @user.update(avatar: fakeio) # update
    end

    it "isn't triggered when no file was attached" do
      @user.avatar_attacher.expects(:save).never
      @user.save # insert
      @user.save # update
    end
  end

  describe "destroying" do
    it "is triggered on record destroy" do
      @user.update(avatar: fakeio)
      @user.destroy
      refute @user.avatar.exists?
    end

    it "works with backgrounding" do
      @uploader.class.plugin :backgrounding
      @attacher.class.delete { |data| self.class.delete(data) }
      @user.update(avatar: fakeio)
      @user.destroy
      refute @user.avatar.exists?
    end
  end

  describe "backgrounding" do
    it "doesn't raise errors when record wasn't found" do
      @uploader.class.plugin :backgrounding
      @attacher.class.promote { |data| record.delete; self.class.promote(data) }
      @attacher.class.delete { |data| record.delete; self.class.delete(data) }
      @user.update(avatar: fakeio)
      @user.destroy
    end

    it "is triggered only when attachment has changed" do
      @uploader.class.plugin :backgrounding
      @attacher.class.promote { |data| @f = Fiber.new{self.class.promote(data)} }
      @user.update(avatar: fakeio)
      fiber = @user.avatar_attacher.instance_variable_get("@f")
      @user.save
      assert_equal fiber, @user.avatar_attacher.instance_variable_get("@f")
    end
  end

  it "allows including attachment model to non-ActiveRecord objects" do
    uploader = @uploader
    Struct.new(:avatar_data) { include uploader.class[:avatar] }
  end
end
