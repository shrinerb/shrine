require "test_helper"
require "shrine/plugins/default_url"

describe Shrine::Plugins::DefaultUrl do
  before do
    @attacher = attacher do
      plugin(:default_url) { |context| context }
    end
  end

  it "returns block value when attachment is missing" do
    assert_equal Hash[name: :avatar, record: @attacher.record],             @attacher.url
    assert_equal Hash[name: :avatar, record: @attacher.record, foo: "foo"], @attacher.url(foo: "foo")
    assert_equal Hash[name: :avatar, record: @attacher.record],             @attacher.url(name: :other)
  end

  it "returns attachment URL if attachmet is present" do
    @attacher.assign(fakeio)
    assert_equal "memory://#{@attacher.get.id}", @attacher.url
  end

  it "doesn't require a block to be given" do
    @attacher = attacher { plugin :default_url }
    assert_equal nil, @attacher.url
  end

  it "doesn't override previously set default URL if no block is given" do
    @attacher.shrine_class.plugin :default_url
    refute_equal nil, @attacher.url
  end
end
