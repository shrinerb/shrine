require "test_helper"
require "shrine/plugins/activerecord"
require "active_record"

describe Shrine::Plugins::Activerecord do
  before do
    @uploader = uploader { plugin :activerecord }

    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Base.connection.create_table(:users) do |t|
      t.string :name
      t.text :avatar_data
    end
    ActiveRecord::Base.raise_in_transactional_callbacks = true

    user_class = Object.const_set("User", Class.new(ActiveRecord::Base))
    user_class.table_name = :users
    user_class.include @uploader.class[:avatar]

    @user = user_class.new
    @attacher = @user.avatar_attacher
  end

  after do
    ActiveRecord::Base.remove_connection
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
    it "is triggered when attachment changes" do
      @user.update(avatar: fakeio("file1")) # insert
      refute @user.changed?
      assert_equal "store", @user.avatar.storage_key
      assert_equal "file1", @user.avatar.read

      @user.update(avatar: fakeio("file2")) # update
      refute @user.changed?
      assert_equal "store", @user.avatar.storage_key
      assert_equal "file2", @user.avatar.read
    end

    it "isn't triggered when attachment didn't change" do
      @user.update(avatar: fakeio("file"))
      attachment = @user.avatar
      @user.update(name: "Name")
      assert_equal attachment, @user.avatar
    end

    it "is triggered after transaction commits" do
      @user.class.transaction do
        @user.update(avatar: fakeio("file2"))
        assert_equal "cache", @user.avatar.storage_key
      end
      assert_equal "store", @user.avatar.storage_key
    end

    it "triggers callbacks" do
      @user.class.before_save do
        @promote_callback = true if avatar.storage_key == "store"
      end
      @user.update(avatar: fakeio)
      assert @user.instance_variable_get("@promote_callback")
    end

    it "updates only the attachment column" do
      @user.update(avatar_data: @attacher.cache!(fakeio).to_json)
      @user.class.update_all(name: "Name")
      @attacher.promote
      @user.reload
      assert_equal "store", @user.avatar.storage_key
      assert_equal "Name",  @user.name
    end

    it "bypasses validations" do
      @user.class.validate { errors.add(:base, "Invalid") }
      @user.avatar = fakeio
      @user.save(validate: false)
      refute @user.changed?
      assert_equal "store", @user.avatar.storage_key
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

    it "doesn't raise errors if no file is attached" do
      @user.save
      @user.destroy
    end
  end

  it "works with backgrounding" do
    @uploader.class.plugin :backgrounding
    @attacher.class.promote { |data| self.class.promote(data) }
    @attacher.class.delete { |data| self.class.delete(data) }

    @user.update(avatar: fakeio)
    assert_equal "store", @user.reload.avatar.storage_key

    @user.destroy
    refute @user.avatar.exists?
  end

  it "returns nil when record is not found" do
    assert_equal nil, @attacher.class.find_record(@user.class, "foo")
  end

  it "raises an appropriate exception when column is missing" do
    @user.class.include @uploader.class[:missing]
    error = assert_raises(NoMethodError) { @user.missing = fakeio }
    assert_match "undefined method `missing_data'", error.message
  end

  it "allows including attachment module to non-ActiveRecord models" do
    klass = Struct.new(:avatar_data)
    klass.include @uploader.class[:avatar]
  end
end
