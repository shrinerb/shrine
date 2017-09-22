require "test_helper"
require "shrine/plugins/store_dimensions"

describe Shrine::Plugins::StoreDimensions do
  before do
    @uploader = uploader { plugin :store_dimensions, analyzer: :fastimage }
    @shrine = @uploader.class
  end

  describe ":fastimage analyzer" do
    it "extracts dimensions from files" do
      dimensions = @shrine.extract_dimensions(image)
      assert_equal [100, 67], dimensions
    end

    it "extracts dimensions from non-files" do
      dimensions = @shrine.extract_dimensions(fakeio(image.read))
      assert_equal [100, 67], dimensions
    end
  end

  it "allows storing with custom extractor" do
    @shrine.plugin :store_dimensions, analyzer: ->(io){[5, 10]}
    dimensions = @shrine.extract_dimensions(fakeio)
    assert_equal [5, 10], dimensions

    @shrine.plugin :store_dimensions, analyzer: ->(io, analyzers){analyzers[:fastimage].call(io)}
    dimensions = @shrine.extract_dimensions(image)
    assert_equal [100, 67], dimensions

    @shrine.plugin :store_dimensions, analyzer: ->(io){nil}
    dimensions = @shrine.extract_dimensions(image)
    assert_nil dimensions
  end

  it "always rewinds the IO" do
    @shrine.plugin :store_dimensions, analyzer: ->(io){io.read; [5, 10]}
    @shrine.extract_dimensions(file = image)
    assert_equal 0, file.pos
  end

  describe "dimension methods" do
    it "adds `#width`, `#height` and `#dimensions` to UploadedFile" do
      uploaded_file = @uploader.upload(image)
      assert_equal uploaded_file.metadata["width"],                     uploaded_file.width
      assert_equal uploaded_file.metadata["height"],                    uploaded_file.height
      assert_equal uploaded_file.metadata.values_at("width", "height"), uploaded_file.dimensions
    end

    it "coerces values to Integer" do
      uploaded_file = @uploader.upload(image)
      uploaded_file.metadata["width"] = "48"
      uploaded_file.metadata["height"] = "52"
      assert_equal 48,       uploaded_file.width
      assert_equal 52,       uploaded_file.height
      assert_equal [48, 52], uploaded_file.dimensions
    end

    it "allows metadata values to be missing or nil" do
      uploaded_file = @uploader.upload(image)
      uploaded_file.metadata["width"] = nil
      uploaded_file.metadata.delete("height")
      assert_nil uploaded_file.width
      assert_nil uploaded_file.height
      assert_nil uploaded_file.dimensions
    end
  end

  it "provides access to dimensions analyzers" do
    analyzers = @shrine.dimensions_analyzers
    dimensions = analyzers[:fastimage].call(io = image)
    assert_equal [100, 67], dimensions
    assert_equal 0, io.pos
  end
end
