require "test_helper"
require "shrine/plugins/default_url_options"

describe Shrine::Plugins::DefaultUrlOptions do
  before do
    @uploader = uploader do
      plugin :default_url_options, store: {foo: "foo"}
    end
  end

  it "adds default options" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {
      foo: "foo",
      shrine_metadata: {
        'filename' => nil,
        'size' => 4,
        'mime_type' => nil
      }
    })
    uploaded_file.url
  end

  it "merges default options with custom options" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {
      foo: "foo",
      bar: "bar",
      shrine_metadata: {
        'filename' => nil,
        'size' => 4,
        'mime_type' => nil
      }
    })
    uploaded_file.url(bar: "bar")
  end

  it "allows custom options to override default options" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.storage.expects(:url).with(uploaded_file.id, {
      foo: "overriden",
      shrine_metadata: {
        'filename' => nil,
        'size' => 4,
        'mime_type' => nil
      }
    })
    uploaded_file.url(foo: "overriden")
  end
end
