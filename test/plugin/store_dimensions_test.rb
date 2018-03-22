require "test_helper"
require "shrine/plugins/store_dimensions"

describe Shrine::Plugins::StoreDimensions do
  before do
    @uploader = uploader { plugin :store_dimensions }
    @shrine = @uploader.class
  end

  describe ":fastimage analyzer" do
    before do
      @shrine.plugin :store_dimensions, analyzer: :fastimage
    end

    it "extracts dimensions from files" do
      assert_equal [100, 67], @shrine.extract_dimensions(image)
    end

    it "extracts dimensions from non-files" do
      assert_equal [100, 67], @shrine.extract_dimensions(fakeio(image.read))
    end
  end

  describe ":mini_magick analyzer" do
    before do
      @shrine.plugin :store_dimensions, analyzer: :mini_magick
    end

    it "extracts dimensions from files" do
      assert_equal [100, 67], @shrine.extract_dimensions(image)
    end

    it "extracts dimensions from non-files" do
      assert_equal [100, 67], @shrine.extract_dimensions(fakeio(image.read))
      assert_equal [100, 67], @shrine.extract_dimensions(@uploader.upload(image))
    end
  end

  describe ":ruby_vips analyzer" do
    before do
      @shrine.plugin :store_dimensions, analyzer: :ruby_vips
    end

    it "extracts dimensions from files" do
      assert_equal [100, 67], @shrine.extract_dimensions(image)
    end

    it "extracts dimensions from non-files" do
      assert_equal [100, 67], @shrine.extract_dimensions(fakeio(image.read))
      assert_equal [100, 67], @shrine.extract_dimensions(@uploader.upload(image))
    end
  end

  it "allows storing with custom extractor" do
    @shrine.plugin :store_dimensions, analyzer: ->(io){[5, 10]}
    assert_equal [5, 10], @shrine.extract_dimensions(fakeio)

    @shrine.plugin :store_dimensions, analyzer: ->(io, analyzers){analyzers[:fastimage].call(io)}
    assert_equal [100, 67], @shrine.extract_dimensions(image)

    @shrine.plugin :store_dimensions, analyzer: ->(io){nil}
    assert_nil @shrine.extract_dimensions(image)
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

  it "returns Shrine::Error on unknown analyzer" do
    assert_raises Shrine::Error do
      @shrine.plugin :store_dimensions, analyzer: :foo
      @shrine.extract_dimensions(image)
    end
  end
end
