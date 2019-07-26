require "test_helper"
require "shrine/plugins/dynamic_storage"

describe Shrine::Plugins::DynamicStorage do
  before do
    @uploader = uploader { plugin :dynamic_storage }
    @shrine   = @uploader.class
  end

  it "allows registering a storage with a regex" do
    @shrine.storage(/store_(\w+)/) { |match| match[1].to_sym }

    assert_equal :foo, @shrine.new(:store_foo).storage
    assert_equal :bar, @shrine.new(:store_bar).storage
  end

  it "allows saved storage resolvers to be inherited" do
    @shrine.storage(/store/) { |match| Shrine::Storage::Memory.new }
    subclass = Class.new(@shrine)
    refute_equal subclass.storages[:store], subclass.find_storage(:store)
  end

  it "doesn't clear registered storage resolvers when reapplying" do
    @shrine.storage(/store/) { |match| Shrine::Storage::Memory.new }
    @shrine.plugin :dynamic_storage
    refute_equal @shrine.storages[:store], @shrine.find_storage(:store)
  end

  it "delegates to default behaviour when storage wasn't found" do
    assert_instance_of Shrine::Storage::Memory, @uploader.class.new(:store).storage
  end
end
