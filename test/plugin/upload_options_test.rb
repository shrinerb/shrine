require "test_helper"
require "shrine/plugins/upload_options"

describe Shrine::Plugins::UploadOptions do
  before do
    @uploader = uploader(:store) { plugin :upload_options }
    @shrine = @uploader.class
  end

  it "accepts a block" do
    @shrine.plugin :upload_options, { store: -> (io, context) { Hash[foo: "foo"] } }
    @uploader.storage.expects(:upload).with { |*, **options| options[:foo] == "foo" }
    @uploader.upload(fakeio)
  end

  it "accepts a hash" do
    @shrine.plugin :upload_options, { store: { foo: "foo" } }
    @uploader.storage.expects(:upload).with { |*, **options| options[:foo] == "foo" }
    @uploader.upload(fakeio)
  end

  it "only passes upload options to specified storages" do
    @shrine.plugin :upload_options, { cache: { foo: "foo" } }
    @uploader.storage.expects(:upload).with { |*, **options| !options.key?(:foo) }
    @uploader.upload(fakeio)
  end

  it "takes lower precedence than :upload_options" do
    @shrine.plugin :upload_options, { cache: { foo: "foo" } }
    @uploader.storage.expects(:upload).with { |*, **options| options[:foo] == "bar" }
    @uploader.upload(fakeio, upload_options: { foo: "bar" })
  end

  it "doesn't overwrite existing options when loading the plugin" do
    @shrine.plugin :upload_options, { cache: { foo: "foo" } }
    @shrine.plugin :upload_options, { store: { bar: "bar" } }
    assert_equal Hash[cache: { foo: "foo" }, store: { bar: "bar" }], @shrine.opts[:upload_options]
  end
end
