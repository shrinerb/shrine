require "test_helper"

describe Shrine::Attachment do
  before do
    @shrine = shrine
  end

  describe ".[]" do
    it "calls .new" do
      attachment = @shrine::Attachment[:file, foo: "bar"]

      assert_instance_of @shrine::Attachment, attachment

      assert_equal :file,            attachment.attachment_name
      assert_equal Hash[foo: "bar"], attachment.options
    end
  end

  describe "#initialize" do
    it "symbolizes attachment name" do
      attachment = @shrine::Attachment.new("file")

      assert_equal :file, attachment.attachment_name
    end

    it "accepts additional options" do
      attachment = @shrine::Attachment.new(:file, foo: "bar")

      assert_equal Hash[foo: "bar"], attachment.options
    end
  end

  describe "#inspect" do
    it "is simplified" do
      attachment = @shrine::Attachment.new(:file)

      assert_match "Attachment(file)", attachment.inspect
    end
  end

  describe "#to_s" do
    it "is simplified" do
      attachment = @shrine::Attachment.new(:file)

      assert_match "Attachment(file)", attachment.to_s
    end
  end
end
