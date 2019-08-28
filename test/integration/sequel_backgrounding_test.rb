require "test_helper"
require "./test/support/sequel"

describe "Sequel Backgrounding" do
  before do
    @shrine = shrine do
      plugin :sequel
      plugin :backgrounding
    end

    user_class = Class.new(Sequel::Model)
    user_class.set_dataset(:users)
    user_class.include @shrine::Attachment.new(:avatar)

    @user = user_class.new
  end

  specify "promotion" do
    # promote immediately to test that the record is saved before background
    # job is kicked off
    @user.avatar_attacher.promote_block do |attacher|
      record = attacher.record.class.with_pk!(attacher.record.id)

      attacher.class
        .retrieve(model: record, name: attacher.name, file: attacher.file_data)
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
      @job = Fiber.new do
        record = attacher.record.class.with_pk!(attacher.record.id)

        attacher.class
          .retrieve(model: record, name: attacher.name, file: attacher.file_data)
          .atomic_promote
      end
    end

    @user.avatar = fakeio
    @user.save

    @user.destroy # doesn't delete cached file

    assert_raises Sequel::NoMatchingRow do
      @job.resume
    end
  end
end
