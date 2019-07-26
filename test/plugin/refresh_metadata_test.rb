require "test_helper"
require "shrine/plugins/refresh_metadata"
require "dry-monitor"

describe Shrine::Plugins::RefreshMetadata do
  before do
    @uploader = uploader { plugin :refresh_metadata }
    @shrine   = @uploader.class
  end

  describe "UploadedFile" do
    describe "#refresh_metadata!" do
      it "re-extracts metadata" do
        file = @uploader.upload fakeio("content", filename: "file.txt", content_type: "text/plain")
        file.metadata.delete("size")
        file.refresh_metadata!

        assert_equal 7,            file.metadata["size"]
        assert_equal "file.txt",   file.metadata["filename"]
        assert_equal "text/plain", file.metadata["mime_type"]
      end

      it "keeps any custom metadata" do
        file = @uploader.upload(fakeio)
        file.metadata["custom"] = "custom"
        file.refresh_metadata!

        assert_equal "custom", file.metadata["custom"]
      end

      it "forwards a Shrine::UploadedFile" do
        file = @uploader.upload(fakeio)

        @shrine.class_eval do
          def extract_metadata(io, **options)
            metadata = super
            metadata["file"] = io.is_a?(Shrine::UploadedFile)
            metadata
          end
        end

        file.refresh_metadata!

        assert_equal true, file.metadata["file"]
      end

      it "accepts additional context and forwards it" do
        file = @uploader.upload(fakeio)

        @shrine.class_eval do
          def extract_metadata(io, foo:, **options)
            metadata = super
            metadata["foo"] = foo
            metadata
          end
        end

        file.refresh_metadata!(foo: "bar")

        assert_equal "bar", file.metadata["foo"]
      end

      it "doesn't re-open an already open uploaded file" do
        file = @uploader.upload(fakeio("content"))
        file.metadata.delete("size")

        file.open do
          file.storage.expects(:open).never
          file.refresh_metadata!
        end

        assert_equal 7, file.metadata["size"]
      end

      it "doesn't mutate the data hash" do
        file = @uploader.upload(fakeio)

        data = file.data
        data["metadata"] = {}

        file.refresh_metadata!

        assert_empty data["metadata"]
        refute_empty file.data["metadata"]
      end

      it "triggers metadata event" do
        @shrine.plugin :instrumentation,
          notifications: Dry::Monitor::Notifications.new(:test),
          log_events: %i[metadata]

        file = @uploader.upload(fakeio)

        assert_logged /^Metadata/ do
          file.refresh_metadata!
        end
      end
    end
  end
end
