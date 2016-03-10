require "test_helper"

describe "the default_url_options plugin" do
  before do
    @uploader = uploader do
      plugin :default_url_options, store: {foo: "foo"}
    end
  end

  it "adds default options" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "foo"})
    uploaded_file.url
  end

  it "merges default options with custom options" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "foo", bar: "bar"})
    uploaded_file.url(bar: "bar")
  end

  it "allows custom options to override default options" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "overriden"})
    uploaded_file.url(foo: "overriden")
  end
end
