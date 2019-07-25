require "test_helper"
require "shrine/plugins/default_url_options"

describe Shrine::Plugins::DefaultUrlOptions do
  before do
    @uploader = uploader { plugin :default_url_options }
  end

  it "adds default options statically" do
    @uploader.class.plugin :default_url_options, store: {foo: "foo"}
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "foo"})
    uploaded_file.url
  end

  it "adds default options dynamically" do
    @uploader.class.plugin :default_url_options, store: ->(io, **options) do
      raise unless io.is_a?(Shrine::UploadedFile)
      raise unless options.is_a?(Hash) && options.key?(:bar)
      {foo: "foo"}
    end
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "foo", bar: "bar"})
    uploaded_file.url(bar: "bar")
  end

  it "merges default options with custom options" do
    @uploader.class.plugin :default_url_options, store: {foo: "foo"}
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "foo", bar: "bar"})
    uploaded_file.url(bar: "bar")
  end

  it "allows direct options to override default options" do
    @uploader.class.plugin :default_url_options, store: {foo: "foo"}
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "overriden"})
    uploaded_file.url(foo: "overriden")
  end

  it "handles nil values" do
    @uploader.class.plugin :default_url_options, store: nil
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "foo"})
    uploaded_file.url(foo: "foo")

    @uploader.class.plugin :default_url_options, store: ->(io, **options) {}
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "foo"})
    uploaded_file.url(foo: "foo")
  end

  it "allows user to override passed options" do
    @uploader.class.plugin :default_url_options, store: ->(io, options) do
      { foo: "#{options.delete(:foo)} bar" }
    end

    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {foo: "foo bar"})
    uploaded_file.url(foo: "foo")
  end
end
