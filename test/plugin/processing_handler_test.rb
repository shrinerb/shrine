require "test_helper"
require "shrine/plugins/processing_handler"

describe Shrine::Plugins::ProcessingHandler do
  before do
    @uploader = uploader { plugin :processing_handler }
  end

  it "executes defined processing" do
    @uploader.class.process(:phase) { |io, context| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("file"), phase: :phase)
    assert_equal "elif", uploaded_file.read
  end

  it "executes in context of uploader, and passes right variables" do
    @uploader.class.process(:phase) do |io, context|
      raise unless self.is_a?(Shrine)
      raise unless io.respond_to?(:read)
      raise unless context.is_a?(Hash) && context.key?(:phase)
      FakeIO.new(io.read.reverse)
    end
    @uploader.upload(fakeio("file"), phase: :phase)
  end

  it "executes all defined blocks where output of previous is input to next" do
    @uploader.class.process(:phase) { |io, context| FakeIO.new("changed") }
    @uploader.class.process(:phase) { |io, context| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("file"), phase: :phase)
    assert_equal "degnahc", uploaded_file.read
  end

  it "allows blocks to return nil" do
    @uploader.class.process(:phase) { |io, context| nil }
    @uploader.class.process(:phase) { |io, context| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("file"), phase: :phase)
    assert_equal "elif", uploaded_file.read
  end

  it "executes defined blocks only if phases match" do
    @uploader.class.process(:phase) { |io, context| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("file"))
    assert_equal "file", uploaded_file.read
  end

  it "has #process return nil when there are no blocks defined" do
    assert_equal nil, @uploader.process(fakeio)
  end
end
