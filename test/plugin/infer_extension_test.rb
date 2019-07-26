require "test_helper"
require "shrine/plugins/infer_extension"
require "dry-monitor"

describe Shrine::Plugins::InferExtension do
  before do
    @uploader = uploader { plugin :infer_extension }
    @shrine   = @uploader.class
  end

  describe ":mime_types analyzer" do
    before do
      @shrine.plugin :infer_extension, inferrer: :mime_types
    end

    it "determines extension from MIME type" do
      assert_equal ".png", @shrine.infer_extension("image/png")
    end

    it "chooses one extension from available extensions" do
      assert_equal ".jpeg", @shrine.infer_extension("image/jpeg")
    end

    it "returns empty string when it couldn't determine extension" do
      assert_nil @shrine.infer_extension("foo")
    end
  end

  describe ":mini_mime analyzer" do
    before do
      @shrine.plugin :infer_extension, inferrer: :mini_mime
    end

    it "determines extension from MIME type" do
      assert_equal ".png", @shrine.infer_extension("image/png")
    end

    it "chooses one extension from available extensions" do
      assert_equal ".jpeg", @shrine.infer_extension("image/jpeg")
    end

    it "returns empty string when it couldn't determine extension" do
      assert_nil @shrine.infer_extension("foo")
    end
  end

  describe "with instrumentation" do
    before do
      @shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)
    end

    it "logs inferring extension" do
      @shrine.plugin :infer_extension

      assert_logged /^Extension \(\d+ms\) – \{.+\}$/ do
        @shrine.infer_extension("image/jpeg")
      end
    end

    it "sends an infer extension event" do
      @shrine.plugin :infer_extension

      @shrine.subscribe(:extension) { |event| @event = event }
      @shrine.infer_extension("image/jpeg")

      refute_nil @event
      assert_equal :extension,   @event.name
      assert_equal "image/jpeg", @event[:mime_type]
      assert_equal @shrine,      @event[:uploader]
      assert_kind_of Integer,    @event.duration
    end

    it "allows swapping log subscriber" do
      @shrine.plugin :infer_extension, log_subscriber: -> (event) { @event = event }

      refute_logged /^Extension/ do
        @shrine.infer_extension("image/jpeg")
      end

      refute_nil @event
    end

    it "allows disabling log subscriber" do
      @shrine.plugin :infer_extension, log_subscriber: nil

      refute_logged /^Extension/ do
        @shrine.infer_extension("image/jpeg")
      end
    end
  end

  it "has a default inferrer" do
    assert_equal ".png", @shrine.infer_extension("image/png")
  end

  it "allows passing a custom inferrer" do
    @shrine.plugin :infer_extension, inferrer: ->(mime_type) { ".foo" }
    assert_equal ".foo", @shrine.infer_extension("image/jpeg")

    @shrine.plugin :infer_extension, inferrer: ->(mime_type, inferrers) { inferrers[:mime_types].call(mime_type) }
    assert_equal ".jpeg", @shrine.infer_extension("image/jpeg")
  end

  it "automatically infers extension when generating location" do
    uploaded_file = @uploader.upload(fakeio(content_type: "image/jpeg"))
    assert_equal "jpeg", uploaded_file.extension
    assert_nil uploaded_file.original_filename
  end

  it "works with the pretty_location plugin" do
    @shrine.plugin :pretty_location
    uploaded_file = @uploader.upload(fakeio(content_type: "image/jpeg"))
    assert_equal "jpeg", uploaded_file.extension
  end

  it "does not replace existing extension when generating location" do
    uploaded_file = @uploader.upload(fakeio(filename: "nature.jpg", content_type: "image/jpeg"))
    assert_equal ".jpg", File.extname(uploaded_file.id)
    assert_equal "nature.jpg", uploaded_file.original_filename
  end

  it "replaces the existing extension on force: true" do
    @shrine.plugin :infer_extension, force: true

    uploaded_file = @uploader.upload(fakeio(filename: "nature.wrong", content_type: "image/jpeg"))
    assert_equal ".jpeg", File.extname(uploaded_file.id)

    uploaded_file = @uploader.upload(fakeio(filename: "nature.mp3", content_type: "image/jpeg"))
    assert_equal ".jpeg", File.extname(uploaded_file.id)

    uploaded_file = @uploader.upload(fakeio(filename: "nature", content_type: "image/jpeg"))
    assert_equal ".jpeg", File.extname(uploaded_file.id)

    uploaded_file = @uploader.upload(fakeio(filename: "nature.jpeg"))
    assert_equal ".jpeg", File.extname(uploaded_file.id)

    uploaded_file = @uploader.upload(fakeio(filename: "nature"))
    assert_equal "", File.extname(uploaded_file.id)
  end

  it "provides access to extension inferrers" do
    inferrers = @shrine.extension_inferrers

    assert_equal ".jpeg", inferrers[:mime_types].call("image/jpeg")
    assert_equal ".jpeg", inferrers[:mini_mime].call("image/jpeg")
  end

  it "returns Shrine::Error on unknown inferrer" do
    assert_raises Shrine::Error do
      @shrine.plugin :infer_extension, inferrer: :foo
      @shrine.infer_extension("image/png")
    end
  end
end
