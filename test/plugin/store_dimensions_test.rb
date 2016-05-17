require "test_helper"

describe "the store_dimensions plugin" do
  before do
    @uploader = uploader { plugin :store_dimensions, analyzer: :fastimage }
  end

  describe ":fastimage" do
    it "extracts dimensions from files" do
      dimensions = @uploader.send(:extract_dimensions, image)
      assert_equal [100, 67], dimensions
    end

    it "extracts dimensions from non-files" do
      dimensions = @uploader.send(:extract_dimensions, fakeio(image.read))
      assert_equal [100, 67], dimensions
    end
  end

  it "allows storing with custom extractor" do
    @uploader = uploader { plugin :store_dimensions, analyzer: ->(io){[5, 10]} }
    dimensions = @uploader.send(:extract_dimensions, fakeio)
    assert_equal [5, 10], dimensions

    @uploader = uploader { plugin :store_dimensions, analyzer: ->(io, analyzers){analyzers[:fastimage].call(io)} }
    dimensions = @uploader.send(:extract_dimensions, image)
    assert_equal [100, 67], dimensions
  end

  it "always rewinds the IO" do
    @uploader = uploader { plugin :store_dimensions, analyzer: ->(io){io.read; [5, 10]} }
    @uploader.send(:extract_dimensions, file = image)
    assert_equal 0, file.pos
  end

  it "gives UploadedFile `width` and `height` methods" do
    uploaded_file = @uploader.upload(image)
    assert_equal uploaded_file.metadata["width"], uploaded_file.width
    assert_equal uploaded_file.metadata["height"], uploaded_file.height
  end

  it "coerces the dimensions to integer" do
    uploaded_file = @uploader.upload(image)
    uploaded_file.metadata["width"] = "48"
    uploaded_file.metadata["height"] = "52"
    assert_equal 48, uploaded_file.width
    assert_equal 52, uploaded_file.height
  end

  it "allows dimensions to be missing or nil" do
    uploaded_file = @uploader.upload(image)
    uploaded_file.metadata["width"] = nil
    uploaded_file.metadata.delete("height")
    assert_equal nil, uploaded_file.width
    assert_equal nil, uploaded_file.height
  end
end
