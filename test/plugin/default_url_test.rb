require "test_helper"

describe "the default_url plugin" do
  before do
    @attacher = attacher { plugin(:default_url) { |context| context.to_json } }
  end

  it "allows specifying the default url in case attachment is missing" do
    assert_includes @attacher.url, '"name":"avatar"'
  end

  it "merges any given url options" do
    assert_includes @attacher.url(foo: "bar"), '"foo":"bar"'
  end

  it "still returns the file URL if it's present" do
    @attacher.assign(fakeio)

    refute_equal "avatar", @attacher.url
  end
end
