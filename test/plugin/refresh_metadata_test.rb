require "test_helper"
require "shrine/plugins/refresh_metadata"
require "dry-monitor"

describe Shrine::Plugins::RefreshMetadata do
  before do
    @attacher = attacher { plugin :refresh_metadata }
    @uploader = @attacher.store
    @shrine   = @uploader.class
  end

  describe "Attacher" do
    describe "#refresh_metadata!" do
      it "re-extracts metadata" do
        @attacher.file = @uploader.upload(fakeio("file"), metadata: false)
        @attacher.refresh_metadata!

        assert_equal 4, @attacher.file.metadata["size"]
      end

      it "writes file data with model plugin" do
        @shrine.plugin :model

        model     = model(file_data: nil)
        @attacher = @shrine::Attacher.from_model(model, :file)

        @attacher.set @uploader.upload(fakeio("file"), metadata: false)
        @attacher.refresh_metadata!

        file = @shrine.uploaded_file(model.file_data)

        assert_equal 4, file.metadata["size"]
      end

      it "forwards additional options for metadata extraction" do
        @attacher.file = @uploader.upload(fakeio("file"))

        @shrine.any_instance.expects(:extract_metadata).with(@attacher.file, { foo: "bar" }).returns({})

        @attacher.refresh_metadata!(foo: "bar")
      end

      it "forwards attacher context for metadata extraction" do
        @attacher.file = @uploader.upload(fakeio("file"))
        @attacher.context[:foo] = "bar"

        @shrine.any_instance.expects(:extract_metadata).with(@attacher.file, { foo: "bar" }).returns({})

        @attacher.refresh_metadata!
      end
    end
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

        empty_hash = {}
        @shrine.any_instance.expects(:extract_metadata).with(file, **empty_hash).returns({})

        file.refresh_metadata!
      end

      it "forwards additional options for metadata extraction" do
        file = @uploader.upload(fakeio)

        @shrine.any_instance.expects(:extract_metadata).with(file, { foo: "bar" }).returns({})

        file.refresh_metadata!(foo: "bar")
      end

      it "overwrites all metadata when replace is true" do
        file = @uploader.upload(fakeio("content"))
        file.metadata["size"]= 100
        file.metadata["custom"] = "custom"
        file.refresh_metadata!(replace: true)
        refute_includes file.metadata.keys, "custom"
        assert_equal 7, file.metadata["size"]
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
