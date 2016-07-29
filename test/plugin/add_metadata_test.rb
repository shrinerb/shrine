require "test_helper"
require "shrine/plugins/add_metadata"

describe Shrine::Plugins::AddMetadata do
  before do
    @uploader = uploader { plugin :add_metadata }
  end

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
      "value"
    end
    @uploader.upload(fakeio, foo: "bar")
  end

  it "adds the metadata method to UploadedFile" do
    @uploader.class.add_metadata(:custom) { |io, context| "value" }
    uploaded_file = @uploader.upload(fakeio)
    assert_equal "value", uploaded_file.custom
  end
end
