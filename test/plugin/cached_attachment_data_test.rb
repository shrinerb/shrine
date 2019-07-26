require "test_helper"
require "shrine/plugins/cached_attachment_data"

describe Shrine::Plugins::CachedAttachmentData do
  before do
    @attacher = attacher { plugin :cached_attachment_data }
    @shrine   = @attacher.shrine_class
  end

  describe "Attachment" do
    before do
      @model_class = model_class(:file_data)
    end

    describe "#cached_<name>_data" do
      it "returns cached file data" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file = fakeio

        assert_equal model.file.to_json, model.cached_file_data
      end

      it "is not defined for entity attachments" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file, type: :entity)

        refute @model_class.method_defined?(:cached_file_data)
      end
    end
  end

  describe "Attacher" do
    describe "#cached_data" do
      it "returns data of cached changed file" do
        @attacher.attach_cached(fakeio)
        assert_equal @attacher.file.to_json, @attacher.cached_data
      end

      it "returns nil when changed file is not cached" do
        @attacher.attach(fakeio)
        assert_nil @attacher.cached_data
      end

      it "returns nil when cached file is not changed" do
        @attacher.set @shrine.upload(fakeio, :cache)
        assert_nil @attacher.cached_data
      end

      it "returns nil when no file is attached" do
        assert_nil @attacher.cached_data
      end
    end
  end
end
