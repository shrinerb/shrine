require "test_helper"
require "shrine/plugins/remove_attachment"

describe Shrine::Plugins::RemoveAttachment do
  before do
    @attacher = attacher { plugin :remove_attachment }
    @shrine   = @attacher.shrine_class
  end

  describe "Attachment" do
    before do
      @model_class = model_class(:file_data)
    end

    describe "#remove_<name>=" do
      it "deassigns the attachment" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file)

        file  = @shrine.upload(fakeio, :store)
        model = @model_class.new(file_data: file.to_json)
        model.remove_file = "true"

        assert_nil model.file
      end

      it "is not defined for entity attachments" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file, type: :entity)

        refute @model_class.method_defined?(:remove_file=)
      end
    end

    describe "#remove_<name>" do
      it "returns the assigned remove value" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.remove_file = "true"

        assert_equal "true", model.remove_file
      end

      it "is not defined for entity attachments" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file, type: :entity)

        refute @model_class.method_defined?(:remove_file)
      end
    end
  end

  describe "Attacher" do
    describe "#remove=" do
      it "deassigns the attached file on truthy value" do
        @attacher.file = @shrine.upload(fakeio, :store)
        @attacher.remove = "true"

        assert_nil @attacher.file
        assert @attacher.changed?
      end

      it "keeps the file on falsy value" do
        @attacher.file = @shrine.upload(fakeio, :store)

        @attacher.remove = ""
        refute_nil @attacher.file

        @attacher.remove = "0"
        refute_nil @attacher.file

        @attacher.remove = "false"
        refute_nil @attacher.file
      end
    end

    describe "#remove" do
      it "returns the assigned value" do
        @attacher.remove = "true"

        assert_equal "true", @attacher.remove
      end
    end
  end
end
