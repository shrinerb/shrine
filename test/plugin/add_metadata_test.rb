require "test_helper"
require "shrine/plugins/add_metadata"

describe Shrine::Plugins::AddMetadata do
  before do
    @uploader = uploader { plugin :add_metadata }
    @shrine = @uploader.class
  end

  describe "add_metadata" do
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

      it "allows requesting a file object" do
        minitest = self
        @shrine.add_metadata(:custom, file: true) do |file, context|
          minitest.assert_respond_to file, :path
          minitest.assert_equal "content", File.read(file.path)
          "value"
        end

        metadata = @uploader.extract_metadata(StringIO.new("content"))
        assert_equal "value", metadata["custom"]

        uploaded_file = @uploader.upload(fakeio("content"))
        metadata = @uploader.extract_metadata(uploaded_file)
        assert_equal "value", metadata["custom"]
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

      it "allows requesting a file object" do
        minitest = self
        @shrine.add_metadata(file: true) do |file, context|
          minitest.assert_respond_to file, :path
          minitest.assert_equal "content", File.read(file.path)
          { "custom" => "value" }
        end

        metadata = @uploader.extract_metadata(StringIO.new("content"))
        assert_equal "value", metadata["custom"]

        uploaded_file = @uploader.upload(fakeio("content"))
        metadata = @uploader.extract_metadata(uploaded_file)
        assert_equal "value", metadata["custom"]
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

    it "rewinds the file between metadata blocks" do
      @shrine.add_metadata(:foo, file: true) { |file| file.read }
      @shrine.add_metadata(:bar, file: true) { |file| file.read }
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

  describe "metadata_method" do
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
  end
end
