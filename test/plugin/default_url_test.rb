require "test_helper"

describe "the default_url plugin" do
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
end
