require "test_helper"
require "shrine/plugins/refresh_metadata"
require "dry-monitor"

describe Shrine::Plugins::RefreshMetadata do
  before do
    @uploader = uploader { plugin :refresh_metadata }
    @shrine = @uploader.class
  end

  it "re-extracts metadata" do
    uploaded_file = @uploader.upload(fakeio("content", filename: "file.txt", content_type: "text/plain"))
    uploaded_file.metadata.delete("size")
    uploaded_file.refresh_metadata!
    assert_equal 7,            uploaded_file.metadata["size"]
    assert_equal "file.txt",   uploaded_file.metadata["filename"]
    assert_equal "text/plain", uploaded_file.metadata["mime_type"]
  end

  it "keeps any custom metadata" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.metadata["custom"] = "custom"
    uploaded_file.refresh_metadata!
    assert_equal "custom", uploaded_file.metadata["custom"]
  end

  it "forwards a Shrine::UploadedFile" do
    uploaded_file = @uploader.upload(fakeio)
    @shrine.plugin :add_metadata
    @shrine.add_metadata(:uploaded_file) { |io| io.is_a?(Shrine::UploadedFile) }
    uploaded_file.refresh_metadata!
    assert_equal true, uploaded_file.metadata["uploaded_file"]
  end

  it "accepts additional context and forwards it" do
    uploaded_file = @uploader.upload(fakeio)
    @shrine.plugin :add_metadata
    @shrine.add_metadata(:context) { |io, context| context }
    uploaded_file.refresh_metadata!(foo: "bar")
    assert_equal "bar", uploaded_file.metadata["context"][:foo]
  end

  it "doesn't re-open an already open uploaded file" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.metadata.delete("size")
    uploaded_file.open do
      uploaded_file.storage.expects(:open).never
      uploaded_file.refresh_metadata!
    end
    assert_equal 7, uploaded_file.metadata["size"]
  end

  it "doesn't mutate the data hash" do
    uploaded_file = @uploader.upload(fakeio)
    data = uploaded_file.data
    data["metadata"] = {}
    uploaded_file.refresh_metadata!
    assert_empty data["metadata"]
    refute_empty uploaded_file.data["metadata"]
  end

  it "triggers metadata event" do
    @shrine.plugin :instrumentation,
      notifications: Dry::Monitor::Notifications.new(:test),
      log_events: %i[metadata]

    uploaded_file = @uploader.upload(fakeio)

    assert_logged /^Metadata/ do
      uploaded_file.refresh_metadata!
    end
  end
end
