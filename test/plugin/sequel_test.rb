require "test_helper"
require "shrine/plugins/sequel"
require "sequel"

Sequel::Model.cache_anonymous_models = false

describe Shrine::Plugins::Sequel do
  before do
    @uploader = uploader { plugin :sequel }

    db = Sequel.connect("#{"jdbc:" if RUBY_ENGINE == "jruby"}sqlite::memory:")
    db.create_table :users do
      primary_key :id
      column :name, :text
      column :avatar_data, :text
    end

    User = Sequel::Model(db[:users])
    User.include @uploader.class::Attachment.new(:avatar)

    @user = User.new
    @attacher = @user.avatar_attacher
  end

  after do
    Object.send(:remove_const, "User")
  end

  describe "validating" do
    it "adds validation errors to the record" do
      @user.avatar_attacher.class.validate { errors << "error" }
      @user.avatar = fakeio
      refute @user.valid?
      assert_equal Hash[avatar: ["error"]], @user.errors.to_hash
    end
  end

  describe "promoting" do
    it "is triggered when attachment changes" do
      @user.update(avatar: fakeio("file1")) # insert
      refute @user.modified?
      assert_equal "store", @user.avatar.storage_key
      assert_equal "file1", @user.avatar.read

      @user.update(avatar: fakeio("file2")) # update
      refute @user.modified?
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
      @user.class.db.transaction do
        @user.update(avatar: fakeio("file2"))
        assert_equal "cache", @user.avatar.storage_key
      end
      assert_equal "store", @user.avatar.storage_key
    end

    it "triggers callbacks" do
      @user.instance_eval do
        def before_save
          @promote_callback = true if avatar.storage_key == "store"
          super
        end
      end
      @user.update(avatar: fakeio)
      assert @user.instance_variable_get("@promote_callback")
    end

    it "updates only the attachment column" do
      @user.update(avatar_data: @attacher.cache!(fakeio).to_json)
      @user.class.dataset.update(name: "Name")
      @attacher.promote
      @user.reload
      assert_equal "store", @user.avatar.storage_key
      assert_equal "Name",  @user.name
    end

    it "bypasses validations" do
      @user.instance_eval { def validate; errors.add(:base, "Invalid"); end }
      @user.avatar = fakeio
      @user.save(validate: false)
      assert_empty @user.changed_columns
      assert_equal "store", @user.avatar.storage_key
    end
  end

  describe "replacing" do
    it "is triggered on save" do
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.update(avatar: fakeio)
      refute uploaded_file.exists?
    end

    it "is terminated when callback chain is halted" do
      @user.update(avatar: fakeio)
      uploaded_file = @user.avatar
      @user.instance_eval { def before_save; cancel_action; end }
      @user.update(avatar: fakeio) rescue nil
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
    assert_nil @attacher.class.find_record(@user.class, "foo")
  end

  it "raises an appropriate exception when column is missing" do
    @user.class.include @uploader.class::Attachment.new(:missing)
    error = assert_raises(NoMethodError) { @user.missing = fakeio }
    assert_match "undefined method `missing_data'", error.message
  end

  it "allows including attachment model to non-Sequel objects" do
    klass = Struct.new(:avatar_data)
    klass.include @uploader.class::Attachment.new(:avatar)
    refute_respond_to klass.new, :validate
  end
end
