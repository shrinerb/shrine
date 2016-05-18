require "test_helper"

describe "the upload_options plugin" do
  before do
    @uploader = uploader(:store) do
      plugin :upload_options
    end
  end

  it "accepts a block" do
    @uploader.opts[:upload_options] = {store: ->(io, context){Hash[foo: "bar"]}}
    @uploader.storage.instance_eval do
      def upload(io, id, shrine_metadata: {}, **upload_options)
        upload_options.fetch(:foo)
        super
      end
    end

    @uploader.upload(fakeio)
  end

  it "accepts a hash" do
    @uploader.opts[:upload_options] = {store: {foo: "bar"}}
    @uploader.storage.instance_eval do
      def upload(io, id, shrine_metadata: {}, **upload_options)
        upload_options.fetch(:foo)
        super
      end
    end

    @uploader.upload(fakeio)
  end

  it "only passes upload options to specified storages" do
    @uploader.opts[:upload_options] = {cache: {foo: "bar"}}
    @uploader.storage.instance_eval do
      def upload(io, id, shrine_metadata: {}, **upload_options)
        raise if upload_options.any?
        super
      end
    end

    @uploader.upload(fakeio)
  end
end
