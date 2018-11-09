require "test_helper"
require "shrine/plugins/add_metadata"

describe Shrine::Plugins::AddMetadata do
  before do
    @uploader = uploader { plugin :add_metadata }
  end

  describe "add_metadata" do
    describe "with argument" do
      it "adds declared metadata" do
        @uploader.class.add_metadata(:custom) { |io, context| "value" }
        uploaded_file = @uploader.upload(fakeio)
        assert_equal "value", uploaded_file.metadata.fetch("custom")
      end

      it "executes inside uploader and forwards correct arguments" do
        @uploader.class.add_metadata(:custom) do |io, context|
          raise unless self.is_a?(Shrine)
          raise unless io.respond_to?(:read)
          raise unless context.is_a?(Hash) && context.key?(:foo)
        end
        @uploader.upload(fakeio, foo: "bar")
      end

      it "allows returning nil" do
        @uploader.class.add_metadata(:custom) { nil }
        uploaded_file = @uploader.upload(fakeio)
        refute uploaded_file.metadata.key?("custom")
      end

      it "rewinds the IO after extracting metadata" do
        @uploader.class.add_metadata(:custom) { |io, context| io.read }
        uploaded_file = @uploader.upload(fakeio("file"))
        assert_equal "file", uploaded_file.read
      end

      it "adds the metadata method to UploadedFile" do
        @uploader.class.add_metadata(:custom) { |io, context| "value" }
        uploaded_file = @uploader.upload(fakeio)
        assert_equal "value", uploaded_file.custom
      end

      it "includes existing metadata in context" do
        @uploader.class.add_metadata(:extracted_size) { |io, context| context[:metadata]["size"] }
        @uploader.class.add_metadata(:extracted_content_type) { |io, context| context[:metadata]["mime_type"] }
        @uploader.class.add_metadata(:extracted_filename) { |io, context| context[:metadata]["filename"] }
        @uploader.class.add_metadata(:we_added) { |io, context| "added" }
        @uploader.class.add_metadata(:extracted_we_added) { |io, context| context[:metadata]["we_added"] }

        uploaded_file = @uploader.upload(fakeio(filename: "supplied_filename.txt", content_type: "text/plain"))

        assert_equal "added", uploaded_file.extracted_we_added
        assert_equal "supplied_filename.txt", uploaded_file.metadata["extracted_filename"]
        assert_equal "text/plain", uploaded_file.metadata["extracted_content_type"]
        assert_equal uploaded_file.size, uploaded_file.metadata["extracted_size"]
      end
    end

    describe "without argument" do
      it "adds declared metadata" do
        @uploader.class.add_metadata { Hash["custom" => "value"] }
        uploaded_file = @uploader.upload(fakeio)
        assert_equal "value", uploaded_file.metadata.fetch("custom")
      end

      it "accepts symbol keys" do
        @uploader.class.add_metadata { Hash[custom: "value"] }
        uploaded_file = @uploader.upload(fakeio)
        assert_equal "value", uploaded_file.metadata.fetch("custom")
      end

      it "executes inside uploader and forwards correct arguments" do
        @uploader.class.add_metadata do |io, context|
          raise unless self.is_a?(Shrine)
          raise unless io.respond_to?(:read)
          raise unless context.is_a?(Hash) && context.key?(:foo)
        end
        @uploader.upload(fakeio, foo: "bar")
      end

      it "allows returning nil" do
        @uploader.class.add_metadata { nil }
        uploaded_file = @uploader.upload(fakeio)
      end

      it "rewinds the IO after extracting metadata" do
        @uploader.class.add_metadata { |io, context| io.read; nil }
        uploaded_file = @uploader.upload(fakeio("file"))
        assert_equal "file", uploaded_file.read
      end

      it "includes existing metadata in context" do
        @uploader.class.add_metadata(:we_added) { |io, context| "added" }
        @uploader.class.add_metadata do |io, context|
          { extracted_existing_metadata: context[:metadata].dup }
        end

        uploaded_file = @uploader.upload(fakeio(filename: "supplied_filename.txt", content_type: "text/plain"))
        extracted_existing_metadata = uploaded_file.metadata["extracted_existing_metadata"]

        assert_equal "added", extracted_existing_metadata["we_added"]
        assert_equal "supplied_filename.txt", extracted_existing_metadata["filename"]
        assert_equal "text/plain", extracted_existing_metadata["mime_type"]
        assert_equal uploaded_file.size, extracted_existing_metadata["size"]
      end
    end
  end

  describe "metadata_method" do
    it "defines a reader on the uploaded file which returns the metadata" do
      @uploader.class.add_metadata { Hash["custom" => "value"] }
      @uploader.class.metadata_method :custom
      uploaded_file = @uploader.upload(fakeio)
      assert_equal "value", uploaded_file.custom
    end

    it "returns nil if metadata is missing" do
      @uploader.class.metadata_method :custom
      uploaded_file = @uploader.upload(fakeio)
      assert_nil uploaded_file.custom
    end
  end
end
