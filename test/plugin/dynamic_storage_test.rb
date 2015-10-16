require "test_helper"

describe "the dynamic_storage plugin" do
  before do
    @uploader = uploader { plugin :dynamic_storage }
  end

  it "allows registering a storage with a regex" do
    @uploader.class.storage /store_(\w+)/ do |match|
      match[1].to_sym
    end

    assert_equal :foo, @uploader.class.new(:store_foo).storage
    assert_equal :bar, @uploader.class.new(:store_bar).storage
  end

  it "caches the dynamically evaluated storages" do
    @uploader.class.storage /store_(\w+)/ do |match|
      match[1]
    end

    assert_equal @uploader.class.new(:store_foo).storage.object_id,
                 @uploader.class.new(:store_foo).storage.object_id
  end
end
