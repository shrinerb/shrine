require "test_helper"
require "./test/support/sequel"

describe "Sequel & derivatives marshalling" do
  before do
    @shrine = shrine do
      plugin :sequel
      plugin :derivatives
    end

    user_class = Class.new(Sequel::Model)
    user_class.set_dataset(:users)
    user_class.include @shrine::Attachment.new(:avatar)

    @user = user_class.create

    # we can't Marshal anonymous classes
    Shrine::TestUploaderClass = @shrine
    Shrine::TestUserClass = user_class
  end

  after do
    Shrine.send(:remove_const, :TestUserClass)
    Shrine.send(:remove_const, :TestUploaderClass)
  end

  specify "marshalling and unmarshalling don't raise any errors" do
    Marshal.load(Marshal.dump(@user.avatar_attacher))
  end
end
