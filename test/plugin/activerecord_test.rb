require "test_helper"
require "./test/support/activerecord"
require "shrine/plugins/activerecord"

describe Shrine::Plugins::Activerecord do
  before do
    @shrine = shrine { plugin :activerecord }

    user_class = Class.new(ActiveRecord::Base)
    user_class.table_name = :users
    user_class.class_eval do
      # needed for translating validation errors
      def self.model_name
        ActiveModel::Name.new(self, nil, "User")
      end
    end

    @user     = user_class.new
    @attacher = @shrine::Attacher.from_model(@user, :avatar)
  end

  after do
    I18n.backend.reload!
  end

  describe "Attachment" do
    describe "validate" do
      before do
        @shrine.plugin :validation
      end

      it "adds attacher errors to the record" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @attacher.class.validate { errors << "error" }
        @user.avatar = fakeio
        refute @user.valid?
        assert_equal Hash[avatar: ["error"]], @user.errors.to_hash
      end

      it "allows errors to be symbols" do
        @user.class.include @shrine::Attachment.new(:avatar)

        store_translation(
          %i[activerecord errors models user attributes avatar error],
          "translated error"
        )

        @attacher.class.validate { errors << :error }
        @user.avatar = fakeio
        refute @user.valid?
        assert_equal Hash[avatar: ["translated error"]], @user.errors.to_hash
      end

      it "allows errors to be symbols and parameters" do
        @user.class.include @shrine::Attachment.new(:avatar)

        store_translation(
          %i[activerecord errors models user attributes avatar error],
          "translated error: %{param}"
        )

        @attacher.class.validate { errors << [:error, param: "some param"] }
        @user.avatar = fakeio
        refute @user.valid?
        assert_equal Hash[avatar: ["translated error: some param"]], @user.errors.to_hash
      end

      it "is skipped if validations are disabled" do
        @shrine.plugin :activerecord, validations: false
        @user.class.include @shrine::Attachment.new(:avatar)

        @attacher.class.validate { errors << "error" }
        @user.avatar = fakeio
        assert @user.valid?
      end
    end

    describe "before_save" do
      it "calls Attacher#save if attachment has changed" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.avatar = fakeio
        @user.avatar_attacher.expects(:save).once
        @user.save
      end

      it "doesn't call Attacher#save if attachment has not changed" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.name = "Janko"
        @user.avatar_attacher.expects(:save).never
        @user.save
      end

      it "is skipped when callbacks are disabled" do
        @shrine.plugin :activerecord, callbacks: false
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.avatar = fakeio
        @user.avatar_attacher.expects(:save).never
        @user.save
      end
    end

    describe "after_save" do
      it "finalizes attacher when attachment changes on create" do
        @user.class.include @shrine::Attachment.new(:avatar)

        previous_file = @attacher.upload(fakeio)
        @user.avatar_attacher.set(previous_file)

        @user.avatar = fakeio
        @user.save

        assert_equal :store, @user.avatar.storage_key
        refute previous_file.exists?
      end

      it "finalizes attacher when attachment changes on update" do
        @user.class.include @shrine::Attachment.new(:avatar)

        previous_file = @attacher.upload(fakeio)
        @user.avatar_attacher.set(previous_file)
        @user.save

        @user.avatar = fakeio
        @user.save

        assert_equal :store, @user.avatar.storage_key
        refute previous_file.exists?
      end

      it "persists changes after finalization" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.avatar = fakeio
        @user.save
        @user.reload

        assert_equal :store, @user.avatar.storage_key
      end

      it "performs finalization after the transaction commits" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.avatar = fakeio

        @user.class.transaction do
          @user.save
          assert_equal :cache, @user.avatar.storage_key
        end
        assert_equal :store, @user.avatar.storage_key
      end

      it "ignores validation errors" do
        @user.class.include @shrine::Attachment.new(:avatar)
        @user.class.validates_presence_of :name

        @user.avatar = fakeio
        @user.save(validate: false)
        @user.reload

        assert_equal :store, @user.avatar.storage_key
      end

      it "is skipped when callbacks are disabled" do
        @shrine.plugin :activerecord, callbacks: false
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.avatar = fakeio
        @user.save

        assert_equal :cache, @user.avatar.storage_key
      end
    end

    describe "after_destroy" do
      it "deletes attached files" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @attacher.set @attacher.upload(fakeio)
        @user.save

        @user.destroy

        refute @user.avatar.exists?
      end

      it "is skipped when callbacks are disabled" do
        @shrine.plugin :activerecord, callbacks: false
        @user.class.include @shrine::Attachment.new(:avatar)

        @attacher.set @attacher.upload(fakeio)
        @user.save

        @user.destroy

        assert @user.avatar.exists?
      end
    end

    describe "#reload" do
      it "reloads the attacher on ActiveRecord::Base#reload" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.save
        @user.avatar_attacher # ensure attacher is memoized

        file = @attacher.upload(fakeio)
        @user.class.update_all(avatar_data: file.to_json)

        @user.reload

        assert_equal file, @user.avatar
      end

      it "reloads the attacher on ActiveRecord::Base#lock!" do
        # assertions
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.save
        @user.avatar_attacher # ensure attacher is memoized

        file = @attacher.upload(fakeio)
        @user.class.update_all(avatar_data: file.to_json)

        @user.class.transaction { @user.lock! }

        assert_equal file, @user.avatar
      end

      it "preserves state other than the file" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.save
        @user.avatar_attacher(cache: :other_cache)
        @user.avatar_attacher.context[:foo] = "bar"
        @user.reload

        assert_equal :other_cache, @user.avatar_attacher.cache_key
        assert_equal "bar",        @user.avatar_attacher.context[:foo]
      end

      it "doesn't initialize the attacher if it hasn't been initialized" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.save
        @user = @user.class.find(@user.id)
        @user.reload

        refute @user.instance_variable_defined?(:@avatar_attacher)
      end

      it "returns self" do
        @user.class.include @shrine::Attachment.new(:avatar)

        @user.save

        assert_equal @user, @user.reload
      end
    end

    it "can still be included into non-ActiveRecord classes" do
      model_class = model_class(:avatar_data)
      model_class.include @shrine::Attachment.new(:avatar)
    end
  end

  describe "Attacher" do
    describe "JSON columns" do
      [:json, :jsonb].each do |type|
        it "handles #{type} type" do
          # work around Active Record casting assigned values into a string
          @user.class.send(:attr_accessor, :avatar_data)

          columns_hash = @user.class.columns_hash.dup # unfreeze
          columns_hash["avatar_data"] = columns_hash["avatar_data"].dup # unfreeze
          columns_hash["avatar_data"].singleton_class.send(:define_method, :type) { type }
          @user.class.instance_variable_set(:@columns_hash, columns_hash)

          @attacher.load_model(@user, :avatar)
          @attacher.attach(fakeio)

          assert_equal @attacher.file.data, @user.avatar_data

          @attacher.reload

          assert_equal @attacher.file.data, @user.avatar_data
        end
      end
    end

    describe "#atomic_promote" do
      it "promotes cached file to permanent storage" do
        @attacher.attach_cached(fakeio)
        @user.save

        @attacher.atomic_promote

        assert @attacher.stored?
        @attacher.reload
        assert @attacher.stored?
      end

      it "updates the record with promoted file" do
        @attacher.attach_cached(fakeio)
        @user.save

        @attacher.atomic_promote

        @user.reload
        @attacher.reload
        assert @attacher.stored?
      end

      it "returns the promoted file" do
        @attacher.attach_cached(fakeio)
        @user.save

        file = @attacher.atomic_promote

        assert_equal @attacher.file, file
      end

      it "accepts promote options" do
        @attacher.attach_cached(fakeio)
        @user.save

        @attacher.atomic_promote(location: "foo")

        assert_equal "foo", @attacher.file.id
      end

      it "persists any other attribute changes" do
        @attacher.attach_cached(fakeio)
        @user.save

        @user.name = "Janko"
        @attacher.atomic_promote

        assert_equal "Janko", @user.name
        assert_equal "Janko", @user.reload.name
      end

      it "executes the given block before persisting" do
        @attacher.attach_cached(fakeio)
        @user.save

        @attacher.atomic_promote { @user.name = "Janko" }

        assert_equal "Janko", @user.name
        assert_equal "Janko", @user.reload.name
      end

      it "fails on attachment change" do
        @attacher.attach_cached(fakeio)
        @user.save

        @user.class.update_all(avatar_data: nil)

        @user.name = "Janko"
        assert_raises(Shrine::AttachmentChanged) do
          @attacher.atomic_promote { @block_called = true }
        end

        @user.reload
        @attacher.reload

        assert_nil @attacher.file
        assert_nil @user.name
        refute @block_called
      end

      it "respects column serializer" do
        @attacher = @shrine::Attacher.from_model(@user, :avatar, column_serializer: RubySerializer)
        @attacher.attach_cached(fakeio)
        @user.save

        @attacher.atomic_promote

        @user.reload
        @attacher.reload
        assert @attacher.stored?
      end

      it "accepts custom reload strategy" do
        cached_file = @attacher.attach_cached(fakeio)
        @user.save

        @user.class.update_all(avatar_data: nil) # this change will not be detected

        @user.name = "Janko"
        @attacher.atomic_promote(reload: -> (&block) {
          block.call @user.class.new(avatar_data: cached_file.to_json)
        })

        @user.reload
        @attacher.reload
        assert @attacher.stored?
        assert_equal "Janko", @user.name
      end

      it "allows disabling reloading" do
        cached_file = @attacher.attach_cached(fakeio)
        @user.save

        @user.class.update_all(avatar_data: nil) # this change will not be detected

        @user.name = "Janko"
        @attacher.atomic_promote(reload: false)

        @user.reload
        @attacher.reload
        assert @attacher.stored?
        assert_equal "Janko", @user.name
      end

      it "accepts custom persist strategy" do
        @attacher.attach_cached(fakeio)
        @user.save

        @attacher.atomic_promote(persist: -> {
          @user.name = "Janko"
          @user.save
        })

        @user.reload
        @attacher.reload
        assert @attacher.stored?
        assert_equal "Janko", @user.name
      end

      it "allows disabling persistence" do
        @attacher.attach_cached(fakeio)
        @user.save

        @user.name = "Janko"
        @attacher.atomic_promote(persist: false)

        assert @attacher.stored?
        assert_equal "Janko", @user.name

        @user.reload
        @attacher.reload
        assert @attacher.cached?
        assert_nil @user.name
      end

      it "raises NotImplementedError for non-ActiveRecord attacher" do
        @attacher = @shrine::Attacher.new

        assert_raises NotImplementedError do
          @attacher.atomic_promote
        end
      end
    end

    describe "#atomic_persist" do
      it "persists the record" do
        file = @attacher.attach(fakeio)
        @user.save

        @user.name = "Janko"
        @attacher.atomic_persist

        assert_equal "Janko", @user.name
        assert_equal "Janko", @user.reload.name
        assert_equal file,    @attacher.file
      end

      it "executes the given block before persisting" do
        @attacher.attach(fakeio)
        @user.save

        @attacher.atomic_persist { @user.name = "Janko" }

        assert_equal "Janko", @user.name
        assert_equal "Janko", @user.reload.name
      end

      it "fails on attachment change" do
        @attacher.attach(fakeio)
        @user.save

        @user.class.update_all(avatar_data: nil)

        @user.name = "Janko"
        assert_raises(Shrine::AttachmentChanged) do
          @attacher.atomic_persist { @block_called = true }
        end

        @user.reload
        @attacher.reload

        assert_nil @attacher.file
        assert_nil @user.name
        refute @block_called
      end

      it "respects column serializer" do
        @attacher = @shrine::Attacher.from_model(@user, :avatar, column_serializer: RubySerializer)
        @attacher.attach(fakeio)
        @user.save

        @user.name = "Janko"
        @attacher.atomic_persist

        @user.reload
        @attacher.reload
        assert_equal "Janko", @user.name
      end

      it "accepts custom reload strategy" do
        @attacher.attach(fakeio)
        @user.save

        @user.class.update_all(avatar_data: nil) # this change will not be detected

        @user.name = "Name"
        @attacher.atomic_persist(reload: -> (&block) { block.call(@user) })

        assert_equal "Name", @user.reload.name
      end

      it "allows disabling reloading" do
        @attacher.attach(fakeio)
        @user.save

        @user.class.update_all(avatar_data: nil) # this change will not be detected

        @user.name = "Name"
        @attacher.atomic_persist(reload: false)

        assert_equal "Name", @user.reload.name
      end

      it "accepts custom persist strategy" do
        @attacher.attach(fakeio)
        @user.save

        @attacher.atomic_persist(persist: -> {
          @user.name = "Janko"
          @user.save
        })

        assert_equal "Janko", @user.name
        assert_equal "Janko", @user.reload.name
      end

      it "allows disabling persistence" do
        @attacher.attach(fakeio)
        @user.save

        @user.name = "Janko"
        @attacher.atomic_persist(persist: false)

        assert_equal "Janko", @user.name
        assert_nil @user.reload.name
      end

      it "accepts current file" do
        @user.save

        file = @attacher.upload(fakeio)
        @user.class.update_all(avatar_data: file.to_json)

        assert_raises(Shrine::AttachmentChanged) do
          @attacher.atomic_persist
        end

        @user.name = "Janko"
        @attacher.atomic_persist(file)

        assert_equal "Janko", @user.name
        assert_equal "Janko", @user.reload.name
      end

      it "raises NotImplementedError for non-ActiveRecord attacher" do
        @attacher = @shrine::Attacher.new

        assert_raises NotImplementedError do
          @attacher.atomic_persist
        end
      end
    end

    describe "#persist" do
      it "persists the record" do
        file = @attacher.upload(fakeio)
        @user.avatar_data = file.to_json

        @attacher.persist

        assert_equal file.to_json, @user.reload.avatar_data
      end

      it "persists only changes" do
        @user.save
        @user.class.update_all(name: "Janko")

        file = @attacher.upload(fakeio)
        @user.avatar_data = file.to_json

        @attacher.persist

        assert_equal "Janko", @user.reload.name
      end

      it "skips validations" do
        @user.class.validates_presence_of :name

        @user.name = "Janko"
        @user.save(validate: false)

        @user.name = nil
        @attacher.persist

        assert_nil @user.reload.name
      end

      it "triggers callbacks when persisting" do
        @user.save

        after_save_called = false
        @user.class.after_save { after_save_called = true }

        @user.name = "Janko"
        @attacher.persist

        assert after_save_called
      end

      it "raises NotImplementedError for non-ActiveRecord attacher" do
        @attacher = @shrine::Attacher.new

        assert_raises NotImplementedError do
          @attacher.persist
        end
      end
    end
  end

  def store_translation(key, value)
    I18n.backend.store_translations(
      I18n.locale,
      key.reverse.inject(value) { |object, component| { component => object } }
    )
  end
end
