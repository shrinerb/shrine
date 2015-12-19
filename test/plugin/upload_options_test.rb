require "test_helper"

describe "the upload_options plugin" do
  def uploader(options)
    super(:store) { plugin :upload_options, **options  }
  end

  it "adds upload options to key named as the storage" do
    @uploader = uploader(store: ->(io, context) { Hash[foo: "bar"] })
    @uploader.storage.instance_eval do
      def upload(io, id, metadata = {})
        metadata.fetch("memory").fetch(:foo)
        super
      end
    end

    @uploader.upload(fakeio)
  end

  it "accepts a hash" do
    @uploader = uploader(store: {foo: "bar"})
    @uploader.storage.instance_eval do
      def upload(io, id, metadata = {})
        metadata.fetch("memory").fetch(:foo)
        super
      end
    end

    @uploader.upload(fakeio)
  end

  it "doesn't store anything if this isn't the storage" do
    @uploader = uploader(cache: {foo: "bar"})
    @uploader.storage.instance_eval do
      def upload(io, id, metadata = {})
        raise if metadata.key("memory")
        super
      end
    end

    @uploader.upload(fakeio)
  end
end
