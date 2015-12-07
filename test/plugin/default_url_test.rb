require "test_helper"

describe "the default_url plugin" do
  before do
    @attacher = attacher { plugin(:default_url) { |options| options[:name].to_s } }
  end

  it "allows specifying the default url in case attachment is missing" do
    assert_equal "avatar", @attacher.url
  end

  it "still returns the file URL if it's present" do
    @attacher.assign(fakeio)

    refute_equal "avatar", @attacher.url
  end
end
