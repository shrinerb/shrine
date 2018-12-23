require "test_helper"
require "shrine/plugins/validation_helpers"

describe Shrine::Plugins::ValidationHelpers do
  before do
    @attacher = attacher { plugin :validation_helpers }
  end

  describe "#validate_max_size" do
    before do
      @attacher.assign(fakeio("file" * 1024*1024))
    end

    it "adds an error if the file is larger than given size" do
      @attacher.class.validate { validate_max_size(get.size + 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_size(get.size) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_size(get.size - 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_max_size(1024*1024) }
      @attacher.validate
      assert_equal ["is too large (max is 1.0 MB)"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_max_size(1024*1024, message: "should not be larger than 1 MB") }
      @attacher.validate
      assert_equal ["should not be larger than 1 MB"], @attacher.errors

      @attacher.class.validate { validate_max_size(1024*1024, message: ->(max){"should not be larger than #{max/1024/1024} MB"}) }
      @attacher.validate
      assert_equal ["should not be larger than 1 MB"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_max_size(get.size) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_max_size(1) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end
  end

  describe "#validate_min_size" do
    before do
      @attacher.assign(fakeio("file"))
    end

    it "adds an error if the file is smaller than given size" do
      @attacher.class.validate { validate_min_size(get.size - 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_size(get.size) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_size(get.size + 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_min_size(1024*1024) }
      @attacher.validate
      assert_equal ["is too small (min is 1.0 MB)"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_min_size(1024*1024, message: "should not be smaller than 1 MB") }
      @attacher.validate
      assert_equal ["should not be smaller than 1 MB"], @attacher.errors

      @attacher.class.validate { validate_min_size(1024*1024, message: ->(min){"should not be smaller than #{min/1024/1024} MB"}) }
      @attacher.validate
      assert_equal ["should not be smaller than 1 MB"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_min_size(1) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_min_size(get.size + 1) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end
  end

  describe "#validate_max_width" do
    before do
      @attacher.shrine_class.plugin :store_dimensions
      @attacher.assign(image)
    end

    it "adds an error if the file is smaller than given size" do
      @attacher.class.validate { validate_max_width(get.width + 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_width(get.width) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_width(get.width - 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_max_width(1) }
      @attacher.validate
      assert_equal ["is too wide (max is 1 px)"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_max_width(1, message: "should not be wider than 1 px") }
      @attacher.validate
      assert_equal ["should not be wider than 1 px"], @attacher.errors

      @attacher.class.validate { validate_max_width(1, message: ->(max){"should not be wider than #{max} px"}) }
      @attacher.validate
      assert_equal ["should not be wider than 1 px"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_max_width(200) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_max_width(1) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end

    deprecated "doesn't add an error message when width is nil" do
      @attacher.assign(fakeio)
      @attacher.class.validate { @validation_passed = validate_max_width(200) }
      @attacher.validate
      assert_empty @attacher.errors
      assert_nil @validation_passed
    end
  end

  describe "#validate_min_width" do
    before do
      @attacher.shrine_class.plugin :store_dimensions
      @attacher.assign(image)
    end

    it "adds an error if the file is smaller than given size" do
      @attacher.class.validate { validate_min_width(get.width - 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_width(get.width) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_width(get.width + 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_min_width(200) }
      @attacher.validate
      assert_equal ["is too narrow (min is 200 px)"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_min_width(200, message: "should not be narrower than 200 px") }
      @attacher.validate
      assert_equal ["should not be narrower than 200 px"], @attacher.errors

      @attacher.class.validate { validate_min_width(200, message: ->(max){"should not be narrower than #{max} px"}) }
      @attacher.validate
      assert_equal ["should not be narrower than 200 px"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_min_width(1) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_min_width(200) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end

    deprecated "doesn't add an error message when width is nil" do
      @attacher.assign(fakeio)
      @attacher.class.validate { @validation_passed = validate_min_width(200) }
      @attacher.validate
      assert_empty @attacher.errors
      assert_nil @validation_passed
    end
  end

  describe "#validate_max_height" do
    before do
      @attacher.shrine_class.plugin :store_dimensions
      @attacher.assign(image)
    end

    it "adds an error if the file is smaller than given size" do
      @attacher.class.validate { validate_max_height(get.height + 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_height(get.height) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_height(get.height - 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_max_height(1) }
      @attacher.validate
      assert_equal ["is too tall (max is 1 px)"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_max_height(1, message: "should not be taller than 1 px") }
      @attacher.validate
      assert_equal ["should not be taller than 1 px"], @attacher.errors

      @attacher.class.validate { validate_max_height(1, message: ->(max){"should not be taller than #{max} px"}) }
      @attacher.validate
      assert_equal ["should not be taller than 1 px"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_max_height(200) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_max_height(1) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end

    deprecated "doesn't add an error message when height is nil" do
      @attacher.assign(fakeio)
      @attacher.class.validate { @validation_passed = validate_max_height(200) }
      @attacher.validate
      assert_empty @attacher.errors
      assert_nil @validation_passed
    end
  end

  describe "#validate_min_height" do
    before do
      @attacher.shrine_class.plugin :store_dimensions
      @attacher.assign(image)
    end

    it "adds an error if the file is smaller than given size" do
      @attacher.class.validate { validate_min_height(get.height - 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_height(get.height) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_height(get.height + 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_min_height(200) }
      @attacher.validate
      assert_equal ["is too short (min is 200 px)"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_min_height(200, message: "should not be shorter than 200 px") }
      @attacher.validate
      assert_equal ["should not be shorter than 200 px"], @attacher.errors

      @attacher.class.validate { validate_min_height(200, message: ->(max){"should not be shorter than #{max} px"}) }
      @attacher.validate
      assert_equal ["should not be shorter than 200 px"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_min_height(1) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_min_height(200) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end

    deprecated "doesn't add an error message when height is nil" do
      @attacher.assign(fakeio)
      @attacher.class.validate { @validation_passed = validate_min_height(200) }
      @attacher.validate
      assert_empty @attacher.errors
      assert_nil @validation_passed
    end
  end

  describe "#validate_mime_type_inclusion" do
    before do
      @attacher.assign(fakeio(content_type: "image/jpeg"))
    end

    it "adds an error when mime_type is not in the whitelist" do
      @attacher.class.validate { validate_mime_type_inclusion(["image/jpeg"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_mime_type_inclusion(["image/jpeg", "image/png"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_mime_type_inclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "handles blank mime type" do
      @attacher.assign(fakeio(content_type: nil))
      @attacher.class.validate { validate_mime_type_inclusion(["image/jpeg"]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_mime_type_inclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal ["isn't of allowed type (allowed types: video/mpeg)"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_mime_type_inclusion(["video/mpeg"], message: "must be a video") }
      @attacher.validate
      assert_equal ["must be a video"], @attacher.errors

      @attacher.class.validate { validate_mime_type_inclusion(["video/mpeg"], message: ->(whitelist){"must be #{whitelist.join(", ")}"}) }
      @attacher.validate
      assert_equal ["must be video/mpeg"], @attacher.errors
    end

    it "handles multiline mime types" do
      @attacher.assign(fakeio(content_type: "video/mpeg\nfoo"))
      @attacher.class.validate { validate_mime_type_inclusion ["video/mpeg"] }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_mime_type_inclusion(["image/jpeg"]) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_mime_type_inclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end

    deprecated "accepts regexes" do
      @attacher.class.validate { validate_mime_type_inclusion([/image/]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_mime_type_inclusion([/video/]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end
  end

  describe "#validate_mime_type_exclusion" do
    before do
      @attacher.assign(fakeio(content_type: "video/mpeg"))
    end

    it "adds an error when mime_type is not in the whitelist" do
      @attacher.class.validate { validate_mime_type_exclusion(["image/jpeg"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_mime_type_exclusion(["image/jpeg", "image/png"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_mime_type_exclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "handles blank mime type" do
      @attacher.assign(fakeio(content_type: nil))
      @attacher.class.validate { validate_mime_type_exclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_mime_type_exclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal ["is of forbidden type"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_mime_type_exclusion(["video/mpeg"], message: "mustn't be a video") }
      @attacher.validate
      assert_equal ["mustn't be a video"], @attacher.errors

      @attacher.class.validate { validate_mime_type_exclusion(["video/mpeg"], message: ->(whitelist){"mustn't be #{whitelist.join(", ")}"}) }
      @attacher.validate
      assert_equal ["mustn't be video/mpeg"], @attacher.errors
    end

    it "handles multiline mime types" do
      @attacher.assign(fakeio(content_type: "video/mpeg\nfoo"))
      @attacher.class.validate { validate_mime_type_exclusion ["video/mpeg"] }
      @attacher.validate
      assert_equal 0, @attacher.errors.size
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_mime_type_exclusion(["image/jpeg"]) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_mime_type_exclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end

    deprecated "accepts regexes" do
      @attacher.class.validate { validate_mime_type_exclusion([/image/]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_mime_type_exclusion([/video/]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end
  end

  describe "#validate_extension_inclusion" do
    before do
      @attacher.assign(fakeio(filename: "image.jpg"))
    end

    it "adds an error when extension is not in the whitelist" do
      @attacher.class.validate { validate_extension_inclusion(["jpg"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_extension_inclusion(["jpg", "png"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_extension_inclusion(["mp4"]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "handles blank extension" do
      @attacher.assign(fakeio(filename: nil))
      @attacher.class.validate { validate_extension_inclusion(["jpg"]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_extension_inclusion(["mp4"]) }
      @attacher.validate
      assert_equal ["isn't of allowed format (allowed formats: mp4)"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_extension_inclusion(["mp4"], message: "must be a video") }
      @attacher.validate
      assert_equal ["must be a video"], @attacher.errors

      @attacher.class.validate { validate_extension_inclusion(["mp4"], message: ->(whitelist){"must be #{whitelist.join(", ")}"}) }
      @attacher.validate
      assert_equal ["must be mp4"], @attacher.errors
    end

    it "does a case insensitive match" do
      @attacher.assign(fakeio(filename: "image.JPG"))
      @attacher.class.validate { validate_extension_inclusion ["jpg"] }
      @attacher.validate
      assert_equal 0, @attacher.errors.size
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_extension_inclusion(["jpg"]) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_extension_inclusion(["mp4"]) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end

    deprecated "accepts regexes" do
      @attacher.class.validate { validate_extension_inclusion([/jpe?g/]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_extension_inclusion([/mp4/]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end
  end

  describe "#validate_extension_exclusion" do
    before do
      @attacher.assign(fakeio(filename: "video.mp4"))
    end

    it "adds an error when extension is not in the whitelist" do
      @attacher.class.validate { validate_extension_exclusion(["jpg"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_extension_exclusion(["jpg", "png"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_extension_exclusion(["mp4"]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "handles blank extension" do
      @attacher.assign(fakeio(filename: nil))
      @attacher.class.validate { validate_extension_exclusion(["jpg"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_extension_exclusion(["mp4"]) }
      @attacher.validate
      assert_equal ["is of forbidden format"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_extension_exclusion(["mp4"], message: "must be a video") }
      @attacher.validate
      assert_equal ["must be a video"], @attacher.errors

      @attacher.class.validate { validate_extension_exclusion(["mp4"], message: ->(whitelist){"must be #{whitelist.join(", ")}"}) }
      @attacher.validate
      assert_equal ["must be mp4"], @attacher.errors
    end

    it "does a case insensitive match" do
      @attacher.assign(fakeio(filename: "image.JPG"))
      @attacher.class.validate { validate_extension_exclusion ["jpg"] }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "returns whether the validation succeeded" do
      @attacher.class.validate { @validation_passed = validate_extension_exclusion(["jpg"]) }
      @attacher.validate
      assert_equal true, @attacher.instance_variable_get("@validation_passed")

      @attacher.class.validate { @validation_passed = validate_extension_exclusion(["mp4"]) }
      @attacher.validate
      assert_equal false, @attacher.instance_variable_get("@validation_passed")
    end

    deprecated "accepts regexes" do
      @attacher.class.validate { validate_extension_exclusion([/jpe?g/]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_extension_exclusion([/mp4/]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end
  end

  describe "PRETTY_FILESIZE" do
    it "returns 0.0 B if size = 0" do
      assert_equal "0.0 B", Shrine::Plugins::ValidationHelpers::PRETTY_FILESIZE.call(0)
    end

    it "returns correct units from bytes to yoltabytes" do
      units = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]

      units.each_with_index do |unit, index|
        size = 1024 ** index
        assert_equal "#{1}.0 #{unit}", Shrine::Plugins::ValidationHelpers::PRETTY_FILESIZE.call(size)
      end

      size = 1024 ** 10
      assert_equal "1048576.0 YB", Shrine::Plugins::ValidationHelpers::PRETTY_FILESIZE.call(size)

      units.each_with_index do |unit, index|
        next if index == 0
        size = 1023 * 1024 ** index
        assert_equal "1023.0 #{unit}", Shrine::Plugins::ValidationHelpers::PRETTY_FILESIZE.call(size)
      end
    end
  end

  it "accepts :default_messages" do
    @attacher.shrine_class.plugin :validation_helpers, default_messages: {
      max_size: -> (max) { "is too big" }
    }
    @attacher.class.validate { validate_max_size 1 }
    @attacher.assign(fakeio("file"))
    assert_equal ["is too big"], @attacher.errors
  end

  it "merges default messages when loading the plugin again" do
    @attacher.shrine_class.plugin :validation_helpers, default_messages: {
      max_size: -> (max) { "is too big" }
    }
    @attacher.shrine_class.plugin :validation_helpers, default_messages: {
      mime_type_inclusion: -> (list) { "is forbidden" }
    }
    @attacher.class.validate do
      validate_max_size 1
      validate_mime_type_inclusion %w[image/jpeg]
    end
    @attacher.assign(fakeio("file", content_type: "image/gif"))
    assert_equal ["is too big", "is forbidden"], @attacher.errors
  end
end
