require "test_helper"

describe "the upload_options plugin" do
  before do
    @uploader = uploader(:store) do
      plugin :upload_options
    end
  end

  it "accepts a block" do
    @uploader.opts[:upload_options_options] = {store: ->(io, context){Hash[foo: "bar"]}}
    @uploader.storage.instance_eval do
      def upload(io, id, metadata = {})
        metadata.fetch("memory").fetch(:foo)
        super
      end
    end

    @uploader.upload(fakeio)
  end

  it "accepts a hash" do
    @uploader.opts[:upload_options_options] = {store: {foo: "bar"}}
    @uploader.storage.instance_eval do
      def upload(io, id, metadata = {})
        metadata.fetch("memory").fetch(:foo)
        super
      end
    end

    @uploader.upload(fakeio)
  end

  it "only passes upload options to specified storages" do
    @uploader.opts[:upload_options_options] = {cache: {foo: "bar"}}
    @uploader.storage.instance_eval do
      def upload(io, id, metadata = {})
        raise if metadata.key?("memory")
        super
      end
    end

    @uploader.upload(fakeio)
  end
end
