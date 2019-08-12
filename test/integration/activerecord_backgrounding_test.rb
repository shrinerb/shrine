require "test_helper"
require "./test/support/activerecord"

describe "ActiveRecord Backgrounding" do
  before do
    @shrine = shrine do
      plugin :activerecord
      plugin :backgrounding
    end

    user_class = Class.new(ActiveRecord::Base)
    user_class.table_name = :users
    user_class.class_eval do
      # needed for translating validation errors
      def self.model_name
        ActiveModel::Name.new(self, nil, "User")
      end
    end
    user_class.include @shrine::Attachment.new(:avatar)

    @user = user_class.new
  end

  specify "promotion" do
    # promote immediately to test that the record is saved before background
    # job is kicked off
    @user.avatar_attacher.promote_block do |attacher|
      record = attacher.record.class.find(attacher.record.id)

      attacher.class
        .retrieve(model: record, name: attacher.name, data: attacher.data)
        .atomic_promote
    end

    @user.avatar = fakeio
    @user.save

    assert_equal :cache, @user.avatar.storage_key

    @user.reload

    assert_equal :store, @user.avatar.storage_key
  end

  specify "replacing" do
    @user.avatar_attacher.destroy_block do |attacher|
      @job = Fiber.new do
        attacher = attacher.class.from_data(attacher.data)
        attacher.destroy
      end
    end

    @user.avatar = fakeio
    @user.save

    previous_file = @user.avatar

    @user.update(avatar: fakeio)

    assert previous_file.exists?

    @job.resume

    refute previous_file.exists?
  end

  specify "destroying" do
    @user.avatar_attacher.destroy_block do |attacher|
      @job = Fiber.new do
        attacher = attacher.class.from_data(attacher.data)
        attacher.destroy
      end
    end

    @user.avatar = fakeio
    @user.save
    @user.destroy

    assert @user.avatar.exists?

    @job.resume

    refute @user.avatar.exists?
  end

  specify "destroying during promotion" do
    @user.avatar_attacher.promote_block do |attacher|
      main = Thread.current

      @job = Fiber.new do
        # JRuby implements fibers using threads, and Active Record locks a
        # connection to a specific thread. So, the connection that created the
        # schema will not be reused here, but a new connection will be created
        # instead. This would be fine otherwise, but since we're using an
        # in-memory database, that new connection wouldn't have any knowledge
        # of the schema.
        #
        # To work around Active Record's bad connection pool implementation, we
        # make ActiveRecord think Fiber's thread is the main thread, in order
        # to force it to keep using the same connection.
        Thread.stubs(:current).returns(main) if RUBY_ENGINE == "jruby"

        record = attacher.record.class.find(attacher.record.id)

        attacher.class
          .retrieve(model: record, name: attacher.name, data: attacher.data)
          .atomic_promote
      end
    end

    @user.avatar = fakeio
    @user.save

    @user.destroy # doesn't delete cached file

    assert_raises ActiveRecord::RecordNotFound do
      @job.resume
    end
  end
end
