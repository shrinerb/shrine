require "test_helper"
require "shrine/plugins/url_options"

describe Shrine::Plugins::UrlOptions do
  before do
    @uploader = uploader { plugin :url_options }
    @shrine   = @uploader.class
  end

  describe "UploadedFile" do
    describe "#url" do
      it "adds default options statically" do
        @shrine.plugin :url_options, store: { foo: "foo" }

        file = @uploader.upload(fakeio)
        file.storage.expects(:url).with(file.id, { foo: "foo" })
        file.url
      end

      it "adds default options dynamically" do
        minitest = self

        @uploader.class.plugin :url_options, store: -> (io, options) do
          minitest.assert_kind_of Shrine::UploadedFile, io
          minitest.assert_equal "bar", options[:bar]

          { foo: "foo" }
        end

        file = @uploader.upload(fakeio)
        file.storage.expects(:url).with(file.id, { foo: "foo", bar: "bar" })
        file.url(bar: "bar")
      end

      it "merges default options with direct options" do
        @shrine.plugin :url_options, store: { foo: "foo" }

        file = @uploader.upload(fakeio)
        file.storage.expects(:url).with(file.id, { foo: "foo", bar: "bar" })
        file.url(bar: "bar")
      end

      it "allows direct options to override default options" do
        @shrine.plugin :url_options, store: { foo: "foo" }

        file = @uploader.upload(fakeio)
        file.storage.expects(:url).with(file.id, { foo: "overriden" })
        file.url(foo: "overriden")
      end

      it "handles nil values" do
        @shrine.plugin :url_options, store: nil

        file = @uploader.upload(fakeio)
        file.storage.expects(:url).with(file.id, { foo: "foo" })
        file.url(foo: "foo")

        @shrine.plugin :url_options, store: -> (io, options) {}

        file = @uploader.upload(fakeio)
        file.storage.expects(:url).with(file.id, { foo: "foo" })
        file.url(foo: "foo")
      end

      it "allows overriding passed options" do
        @shrine.plugin :url_options, store: -> (io, options) {
          { foo: "#{options.delete(:foo)} bar" }
        }

        file = @uploader.upload(fakeio)
        file.storage.expects(:url).with(file.id, { foo: "foo bar" })
        file.url(foo: "foo")
      end
    end
  end
end
