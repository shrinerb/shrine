require "test_helper"
require "shrine/plugins/infer_extension"

describe Shrine::Plugins::InferExtension do
  before do
    @uploader = uploader { plugin :infer_extension }
    @shrine = @uploader.class
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
    assert_equal ".jpeg", File.extname(uploaded_file.id)
    assert_nil uploaded_file.original_filename

    uploaded_file = @uploader.upload(fakeio(filename: "nature.jpg", content_type: "image/jpeg"))
    assert_equal ".jpg", File.extname(uploaded_file.id)
    assert_equal "nature.jpg", uploaded_file.original_filename
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
