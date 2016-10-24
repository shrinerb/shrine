require "test_helper"
require "shrine/plugins/upload_options"

describe Shrine::Plugins::UploadOptions do
  before do
    @uploader = uploader(:store) do
      plugin :upload_options
    end
  end

  it "accepts a block" do
    @uploader.opts[:upload_options] = {store: ->(io, context){Hash[foo: "foo"]}}
    @uploader.storage.expects(:upload).with { |*, **options| options[:foo] == "foo" }
    @uploader.upload(fakeio)
  end

  it "accepts a hash" do
    @uploader.opts[:upload_options] = {store: {foo: "foo"}}
    @uploader.storage.expects(:upload).with { |*, **options| options[:foo] == "foo" }
    @uploader.upload(fakeio)
  end

  it "only passes upload options to specified storages" do
    @uploader.opts[:upload_options] = {cache: {foo: "foo"}}
    @uploader.storage.expects(:upload).with { |*, **options| !options.key?(:foo) }
    @uploader.upload(fakeio)
  end

  it "takes lower precedence than :upload_options" do
    @uploader.opts[:upload_options] = {cache: {foo: "foo"}}
    @uploader.storage.expects(:upload).with { |*, **options| options[:foo] == "bar" }
    @uploader.upload(fakeio, upload_options: {foo: "bar"})
  end
end
