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

  it "delegates to default behaviour when storage wasn't found" do
    assert_instance_of Shrine::Storage::Memory, @uploader.class.new(:store).storage
  end
end
