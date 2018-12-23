require "test_helper"
require "shrine/plugins/processing"

describe Shrine::Plugins::Processing do
  before do
    @uploader = uploader { plugin :processing }
    @shrine = @uploader.class
  end

  it "executes defined processing" do
    @shrine.process(:foo) { |io, context| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("file"), action: :foo)
    assert_equal "elif", uploaded_file.read
  end

  it "executes in context of uploader, and passes right variables" do
    @shrine.process(:foo) do |io, context|
      raise unless self.is_a?(Shrine)
      raise unless io.respond_to?(:read)
      raise unless context.is_a?(Hash) && context.key?(:action)
      FakeIO.new(io.read.reverse)
    end
    @uploader.upload(fakeio("file"), action: :foo)
  end

  it "executes all defined blocks where output of previous is input to next" do
    @shrine.process(:foo) { |io, context| FakeIO.new("changed") }
    @shrine.process(:foo) { |io, context| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("file"), action: :foo)
    assert_equal "degnahc", uploaded_file.read
  end

  it "allows blocks to return nil" do
    @shrine.process(:foo) { |io, context| nil }
    @shrine.process(:foo) { |io, context| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("file"), action: :foo)
    assert_equal "elif", uploaded_file.read
  end

  it "executes defined blocks only if phases match" do
    @shrine.process(:foo) { |io, context| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("file"))
    assert_equal "file", uploaded_file.read
  end

  it "has #process return nil when there are no blocks defined" do
    assert_nil @uploader.process(fakeio)
  end

  it "doesn't overwrite existing definitions when loading the plugin" do
    @shrine.process(:foo) { |io, context| FakeIO.new("processed") }
    @shrine.plugin :processing
    uploaded_file = @uploader.upload(fakeio, action: :foo)
    assert_equal "processed", uploaded_file.read
  end
end
