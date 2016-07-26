require "test_helper"
require "shrine/plugins/metadata"

describe Shrine::Plugins::Metadata do
  before do
    @uploader = uploader { plugin :metadata }
  end

  it "adds declared metadata" do
    @uploader.class.metadata("custom") { |io, context| "value" }
    uploaded_file = @uploader.upload(fakeio)
    assert_equal "value", uploaded_file.metadata.fetch("custom")
  end

  it "executes inside uploader and forwards correct arguments" do
    @uploader.class.metadata("custom") do |io, context|
      raise unless self.is_a?(Shrine)
      raise unless io.respond_to?(:read)
      raise unless context.is_a?(Hash) && context.key?(:foo)
      "value"
    end
    @uploader.upload(fakeio, foo: "bar")
  end

  it "allows overriding existing metadata" do
    @uploader.class.metadata("mime_type") { |io, context| "overriden" }
    uploaded_file = @uploader.upload(fakeio(content_type: "value"))
    assert_equal "overriden", uploaded_file.mime_type
  end
end
