require "test_helper"
require "shrine/plugins/add_metadata"

describe Shrine::Plugins::AddMetadata do
  before do
    @uploader = uploader { plugin :add_metadata }
    @shrine   = @uploader.class
  end

  describe "Shrine.add_metadata" do
    describe "with argument" do
      it "adds declared metadata" do
        @shrine.add_metadata(:custom) { |io, context| "value" }
        metadata = @uploader.extract_metadata(fakeio)
        assert_equal "value", metadata.fetch("custom")
        assert_kind_of Integer, metadata["size"]
      end

      it "allows returning nil" do
        @shrine.add_metadata(:custom) { nil }
        metadata = @uploader.extract_metadata(fakeio)
        assert_nil metadata.fetch("custom")
      end

      it "adds the metadata method to UploadedFile" do
        @shrine.add_metadata(:custom) { |io, context| "value" }
        uploaded_file = @uploader.upload(fakeio)
        assert_equal "value", uploaded_file.custom
      end
    end

    describe "without argument" do
      it "adds declared metadata" do
        @shrine.add_metadata { Hash["custom" => "value"] }
        metadata = @uploader.extract_metadata(fakeio)
        assert_equal "value", metadata.fetch("custom")
        assert_kind_of Integer, metadata["size"]
      end

      it "accepts symbol keys" do
        @shrine.add_metadata { Hash[custom: "value"] }
        metadata = @uploader.extract_metadata(fakeio)
        assert_equal "value", metadata.fetch("custom")
      end

      it "allows returning nil" do
        @shrine.add_metadata { nil }
        metadata = @uploader.extract_metadata(fakeio)
        assert_equal %w[filename size mime_type], metadata.keys
      end
    end

    describe "with skip_nil option" do
      it "does not ignore not nil values" do
        @shrine.add_metadata(:custom, skip_nil: true) { false }
        metadata = @uploader.extract_metadata(fakeio)
        assert_equal false, metadata.fetch("custom")
      end

      it "ignores nil" do
        @shrine.add_metadata(:custom, skip_nil: true) { nil }
        metadata = @uploader.extract_metadata(fakeio)
        assert !metadata.has_key?("custom")
      end
    end

    it "executes inside uploader and forwards correct arguments" do
      minitest = self
      input = fakeio
      @shrine.add_metadata(:custom) do |io, context|
        minitest.assert_kind_of Shrine, self
        minitest.assert_equal input, io
        minitest.assert_instance_of Hash, context
        minitest.assert_equal "bar", context[:foo]
        nil
      end
      @uploader.extract_metadata(input, foo: "bar")
    end

    it "rewinds the IO between metadata blocks" do
      @shrine.add_metadata(:foo) { |io| io.read }
      @shrine.add_metadata(:bar) { |io| io.read }
      metadata = @uploader.extract_metadata(input = fakeio("file"))
      assert_equal "file", metadata["foo"]
      assert_equal "file", metadata["bar"]
      assert_equal "file", input.read
    end

    it "includes existing metadata in context" do
      @shrine.add_metadata(:extracted_size) { |io, context| context[:metadata]["size"] }
      @shrine.add_metadata(:extracted_content_type) { |io, context| context[:metadata]["mime_type"] }
      @shrine.add_metadata(:extracted_filename) { |io, context| context[:metadata]["filename"] }
      @shrine.add_metadata(:we_added) { |io, context| "added" }
      @shrine.add_metadata(:extracted_we_added) { |io, context| context[:metadata]["we_added"] }

      metadata = @uploader.extract_metadata(fakeio(filename: "supplied_filename.txt", content_type: "text/plain"))

      assert_equal "added", metadata["extracted_we_added"]
      assert_equal "supplied_filename.txt", metadata["extracted_filename"]
      assert_equal "text/plain", metadata["extracted_content_type"]
      assert_equal metadata["size"], metadata["extracted_size"]
    end
  end

  describe "Shrine.metadata_method" do
    it "defines a reader on the uploaded file which returns the metadata" do
      @shrine.add_metadata { Hash["custom" => "value"] }
      @shrine.metadata_method :custom
      uploaded_file = @uploader.upload(fakeio)
      assert_equal "value", uploaded_file.custom
    end

    it "returns nil if metadata is missing" do
      @shrine.metadata_method :custom
      uploaded_file = @uploader.upload(fakeio)
      assert_nil uploaded_file.custom
    end

    it "respects inheritance" do
      shrine1 = Class.new(@shrine)
      shrine2 = Class.new(@shrine)

      shrine1.metadata_method :custom

      assert shrine1::UploadedFile.method_defined?(:custom)
      refute shrine2::UploadedFile.method_defined?(:custom)
    end
  end

  it "doesn't overwrite existing definitions when loading the plugin" do
    @shrine.add_metadata(:foo) { |io, context| "bar" }
    @shrine.plugin :add_metadata
    metadata = @uploader.extract_metadata(fakeio)
    assert_equal "bar", metadata["foo"]
  end

  describe "UploadedFile#add_metadata" do
    it "merges metadata" do
      file = @uploader.upload(fakeio, metadata: { "foo" => "foo" })
      file.add_metadata("bar" => "bar")
      assert_equal "foo", file.metadata["foo"]
      assert_equal "bar", file.metadata["bar"]
    end

    it "accepts merge block" do
      file = @uploader.upload(fakeio, metadata: { "nested" => { "foo" => "foo" } })
      file.add_metadata("nested" => { "bar" => "bar" }) { |k, v1, v2| v1.merge(v2) }
      assert_equal "foo", file.metadata["nested"]["foo"]
      assert_equal "bar", file.metadata["nested"]["bar"]
    end

    it "doesn't mutate the metadata hash" do
      file = @uploader.upload(fakeio)
      metadata = file.metadata
      file.add_metadata("foo" => "bar")
      refute_equal metadata, file.metadata
    end
  end

  describe "Attacher#add_metadata" do
    it "merges metadata and writes to the model" do
      @shrine.plugin :model

      attacher = @shrine::Attacher.from_model(model(file_data: nil), :file)
      attacher.attach(fakeio)
      attacher.add_metadata("foo" => "bar")

      file = @shrine.uploaded_file(attacher.record.file_data)
      assert_equal "bar", file.metadata["foo"]
      assert_equal "bar", attacher.file.metadata["foo"]
    end

    it "raises exception if there is no attached file" do
      attacher = @shrine::Attacher.new

      assert_raises Shrine::Error do
        attacher.add_metadata("foo" => "bar")
      end
    end
  end
end
