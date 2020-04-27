require "test_helper"
require "shrine/plugins/validation_helpers"

describe Shrine::Plugins::ValidationHelpers do
  before do
    @attacher = attacher { plugin :validation_helpers }
  end

  describe "#validate_max_size" do
    before do
      @attacher.attach(fakeio("file" * 1024*1024))
    end

    it "adds an error if size is greater than given maximum" do
      @attacher.class.validate { validate_max_size(file.size + 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_size(file.size) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_size(file.size - 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_max_size(1024*1024) }
      @attacher.validate
      assert_equal ["size must not be greater than 1.0 MB"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_max_size(1024*1024, message: "should not be greater than 1 MB") }
      @attacher.validate
      assert_equal ["should not be greater than 1 MB"], @attacher.errors

      @attacher.class.validate { validate_max_size(1024*1024, message: ->(max){"should not be greater than #{max/1024/1024} MB"}) }
      @attacher.validate
      assert_equal ["should not be greater than 1 MB"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_max_size(file.size) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_max_size(1) }
      @attacher.validate
      assert_equal false, validation_passed
    end
  end

  describe "#validate_min_size" do
    before do
      @attacher.attach(fakeio("file"))
    end

    it "adds an error if size is less than given minimum" do
      @attacher.class.validate { validate_min_size(file.size - 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_size(file.size) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_size(file.size + 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_min_size(1024*1024) }
      @attacher.validate
      assert_equal ["size must not be less than 1.0 MB"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_min_size(1024*1024, message: "should not be less than 1 MB") }
      @attacher.validate
      assert_equal ["should not be less than 1 MB"], @attacher.errors

      @attacher.class.validate { validate_min_size(1024*1024, message: ->(min){"should not be less than #{min/1024/1024} MB"}) }
      @attacher.validate
      assert_equal ["should not be less than 1 MB"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_min_size(1) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_min_size(file.size + 1) }
      @attacher.validate
      assert_equal false, validation_passed
    end
  end

  describe "#validate_size" do
    before do
      @attacher.attach(fakeio("file"))
    end

    it "adds an error if size is greater than given maximum" do
      @attacher.class.validate { validate_size 0..2 }
      @attacher.validate
      assert_equal ["size must not be greater than 2.0 B"], @attacher.errors
    end

    it "adds an error if size is less than given minimum" do
      @attacher.class.validate { validate_size 10..14 }
      @attacher.validate
      assert_equal ["size must not be less than 10.0 B"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_size 0..4 }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_size 10..14 }
      @attacher.validate
      assert_equal false, validation_passed
    end
  end

  describe "#validate_max_width" do
    before do
      @attacher.attach(fakeio, metadata: { "width" => 100, "height" => 70 })
    end

    it "adds an error if width is greater than given maximum" do
      @attacher.class.validate { validate_max_width(get["width"] + 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_width(get["width"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_width(get["width"] - 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_max_width(1) }
      @attacher.validate
      assert_equal ["width must not be greater than 1px"], @attacher.errors
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
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_max_width(200) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_max_width(1) }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "fails when width metadata is missing" do
      @attacher.attach(fakeio)
      @attacher.class.validate { validate_max_width(100) }
      assert_raises(Shrine::Error) { @attacher.validate }
    end
  end

  describe "#validate_min_width" do
    before do
      @attacher.attach(fakeio, metadata: { "width" => 100, "height" => 70 })
    end

    it "adds an error if width is less than given minimum" do
      @attacher.class.validate { validate_min_width(get["width"] - 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_width(get["width"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_width(get["width"] + 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_min_width(200) }
      @attacher.validate
      assert_equal ["width must not be less than 200px"], @attacher.errors
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
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_min_width(1) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_min_width(200) }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "fails when width metadata is missing" do
      @attacher.attach(fakeio)
      @attacher.class.validate { validate_min_width(1) }
      assert_raises(Shrine::Error) { @attacher.validate }
    end
  end

  describe "#validate_width" do
    before do
      @attacher.attach(fakeio, metadata: { "width" => 100, "height" => 70 })
    end

    it "adds an error if width is greater than given maximum" do
      @attacher.class.validate { validate_width 0..10 }
      @attacher.validate
      assert_equal ["width must not be greater than 10px"], @attacher.errors
    end

    it "adds an error if width is less than given minimum" do
      @attacher.class.validate { validate_width 150..200 }
      @attacher.validate
      assert_equal ["width must not be less than 150px"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_width 0..100 }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_width 150..200 }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "fails when width metadata is missing" do
      @attacher.attach(fakeio)
      @attacher.class.validate { validate_width 0..100 }
      assert_raises(Shrine::Error) { @attacher.validate }
    end
  end

  describe "#validate_max_height" do
    before do
      @attacher.attach(fakeio, metadata: { "width" => 100, "height" => 70 })
    end

    it "adds an error if height is greater than given maximum" do
      @attacher.class.validate { validate_max_height(get["height"] + 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_height(get["height"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_height(get["height"] - 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_max_height(1) }
      @attacher.validate
      assert_equal ["height must not be greater than 1px"], @attacher.errors
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
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_max_height(200) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_max_height(1) }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "fails when height metadata is missing" do
      @attacher.attach(fakeio)
      @attacher.class.validate { validate_max_height 100 }
      assert_raises(Shrine::Error) { @attacher.validate }
    end
  end

  describe "#validate_min_height" do
    before do
      @attacher.attach(fakeio, metadata: { "width" => 100, "height" => 70 })
    end

    it "adds an error if height is less than given minimum" do
      @attacher.class.validate { validate_min_height(get["height"] - 1) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_height(get["height"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_height(get["height"] + 1) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_min_height(200) }
      @attacher.validate
      assert_equal ["height must not be less than 200px"], @attacher.errors
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
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_min_height(1) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_min_height(200) }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "fails when height metadata is missing" do
      @attacher.attach(fakeio)
      @attacher.class.validate { validate_min_height 1 }
      assert_raises(Shrine::Error) { @attacher.validate }
    end
  end

  describe "#validate_height" do
    before do
      @attacher.attach(fakeio, metadata: { "width" => 100, "height" => 70 })
    end

    it "adds an error if height is greater than given maximum" do
      @attacher.class.validate { validate_height 0..10 }
      @attacher.validate
      assert_equal ["height must not be greater than 10px"], @attacher.errors
    end

    it "adds an error if height is less than given minimum" do
      @attacher.class.validate { validate_height 150..200 }
      @attacher.validate
      assert_equal ["height must not be less than 150px"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_height 0..100 }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_height 150..200 }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "fails when height metadata is missing" do
      @attacher.attach(fakeio)
      @attacher.class.validate { validate_height 0..100 }
      assert_raises(Shrine::Error) { @attacher.validate }
    end
  end

  describe "#validate_max_dimensions" do
    before do
      @attacher.attach(fakeio, metadata: { "width" => 100, "height" => 70 })
    end

    it "adds an error if width is greater than given maximum" do
      @attacher.class.validate { validate_max_dimensions([get["width"] + 1, get["height"]]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_dimensions([get["width"], get["height"]]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_dimensions([get["width"] - 1, get["height"]]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "adds an error if height is greater than given maximum" do
      @attacher.class.validate { validate_max_dimensions([get["width"], get["height"] + 1]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_dimensions([get["width"], get["height"]]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_max_dimensions([get["width"], get["height"] - 1]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_max_dimensions([50, 50]) }
      @attacher.validate
      assert_equal ["dimensions must not be greater than 50x50"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_max_dimensions([50, 50], message: "should not be larger than 50x50") }
      @attacher.validate
      assert_equal ["should not be larger than 50x50"], @attacher.errors

      @attacher.class.validate { validate_max_dimensions([50, 50], message: ->((w,h)){"should not be larger than #{w}x#{h}"}) }
      @attacher.validate
      assert_equal ["should not be larger than 50x50"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_max_dimensions([100, 100]) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_max_dimensions([10, 10]) }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "raises an error if width or height are missing" do
      @attacher.attach(fakeio)
      @attacher.class.validate { validate_max_dimensions([100, 100]) }
      assert_raises(Shrine::Error) { @attacher.validate }
    end
  end

  describe "#validate_min_dimensions" do
    before do
      @attacher.attach(fakeio, metadata: { "width" => 100, "height" => 70 })
    end

    it "adds an error if width is less than given minimum" do
      @attacher.class.validate { validate_min_dimensions([get["width"] - 1, get["height"]]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_dimensions([get["width"], get["height"]]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_dimensions([get["width"] + 1, get["height"]]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "adds an error if height is less than given minimum" do
      @attacher.class.validate { validate_min_dimensions([get["width"], get["height"] - 1]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_dimensions([get["width"], get["height"]]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_min_dimensions([get["width"], get["height"] + 1]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_min_dimensions([150, 150]) }
      @attacher.validate
      assert_equal ["dimensions must not be less than 150x150"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_min_dimensions([150, 150], message: "should not be smaller than 150x150") }
      @attacher.validate
      assert_equal ["should not be smaller than 150x150"], @attacher.errors

      @attacher.class.validate { validate_min_dimensions([150, 150], message: ->((w,h)){"should not be smaller than #{w}x#{h}"}) }
      @attacher.validate
      assert_equal ["should not be smaller than 150x150"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_min_dimensions([0, 0]) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_min_dimensions([150, 150]) }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "raises an error if width or height are missing" do
      @attacher.attach(fakeio)
      @attacher.class.validate { validate_min_dimensions([0, 0]) }
      assert_raises(Shrine::Error) { @attacher.validate }
    end
  end

  describe "#validate_dimensions" do
    before do
      @attacher.attach(fakeio, metadata: { "width" => 100, "height" => 70 })
    end

    it "adds an error if dimensions are greater than given maximum" do
      @attacher.class.validate { validate_dimensions([0..50, 0..50]) }
      @attacher.validate
      assert_equal ["dimensions must not be greater than 50x50"], @attacher.errors
    end

    it "adds an error if dimensions are smaller than given minimum" do
      @attacher.class.validate { validate_dimensions([150..200, 150..200]) }
      @attacher.validate
      assert_equal ["dimensions must not be less than 150x150"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_dimensions([0..100, 0..100]) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_dimensions([150..200, 150..200]) }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "raises an error if width or height are missing" do
      @attacher.attach(fakeio)
      @attacher.class.validate { validate_dimensions([0..100, 0..100]) }
      assert_raises(Shrine::Error) { @attacher.validate }
    end
  end

  describe "#validate_mime_type_inclusion" do
    before do
      @attacher.attach(fakeio(content_type: "image/jpeg"))
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
      @attacher.attach(fakeio(content_type: nil))
      @attacher.class.validate { validate_mime_type_inclusion(["image/jpeg"]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_mime_type_inclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal ["type must be one of: video/mpeg"], @attacher.errors
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
      @attacher.attach(fakeio(content_type: "video/mpeg\nfoo"))
      @attacher.class.validate { validate_mime_type_inclusion ["video/mpeg"] }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_mime_type_inclusion(["image/jpeg"]) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_mime_type_inclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "is aliased to #validate_mime_type" do
      @attacher.class.validate { validate_mime_type(["video/mpeg"]) }
      @attacher.validate
      assert_equal ["type must be one of: video/mpeg"], @attacher.errors
    end
  end

  describe "#validate_mime_type_exclusion" do
    before do
      @attacher.attach(fakeio(content_type: "video/mpeg"))
    end

    it "adds an error when mime_type is in the blacklist" do
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
      @attacher.attach(fakeio(content_type: nil))
      @attacher.class.validate { validate_mime_type_exclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_mime_type_exclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal ["type must not be one of: video/mpeg"], @attacher.errors
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
      @attacher.attach(fakeio(content_type: "video/mpeg\nfoo"))
      @attacher.class.validate { validate_mime_type_exclusion ["video/mpeg"] }
      @attacher.validate
      assert_equal 0, @attacher.errors.size
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_mime_type_exclusion(["image/jpeg"]) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_mime_type_exclusion(["video/mpeg"]) }
      @attacher.validate
      assert_equal false, validation_passed
    end
  end

  describe "#validate_mime_type_format" do
    before do
      @attacher.attach(fakeio(content_type: "image/jpeg"))
    end

    it "adds an error when mime_type does not match with format" do
      @attacher.class.validate { validate_mime_type_format(%r[\Aimage\/.+\z]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size

      @attacher.class.validate { validate_mime_type_format(%r[\Avideo\/.+\z]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_mime_type_format(%r[\Avideo\/.+\z]) }
      @attacher.validate
      assert_equal ["type must match /\\Avideo\\/.+\\z/"], @attacher.errors
    end

    it "accepts a custom error message" do
      @attacher.class.validate { validate_mime_type_format(%r[\Avideo\/.+\z], message: "must be a video") }
      @attacher.validate
      assert_equal ["must be a video"], @attacher.errors

      @attacher.class.validate { validate_mime_type_format(%r[\Avideo\/.+\z], message: -> (format){"must be a #{format}"}) }
      @attacher.validate
      assert_equal ["must be a (?-mix:\\Avideo\\/.+\\z)"], @attacher.errors
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_mime_type_format(%r[\Aimage\/.+\z]) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_mime_type_format(%r[\Avideo\/.+\z]) }
      @attacher.validate
      assert_equal false, validation_passed
    end
  end

  describe "#validate_extension_inclusion" do
    before do
      @attacher.attach(fakeio(filename: "image.jpg"))
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
      @attacher.attach(fakeio(filename: nil))
      @attacher.class.validate { validate_extension_inclusion(["jpg"]) }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_extension_inclusion(["mp4"]) }
      @attacher.validate
      assert_equal ["extension must be one of: mp4"], @attacher.errors
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
      @attacher.attach(fakeio(filename: "image.JPG"))
      @attacher.class.validate { validate_extension_inclusion ["jpg"] }
      @attacher.validate
      assert_equal 0, @attacher.errors.size
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_extension_inclusion(["jpg"]) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_extension_inclusion(["mp4"]) }
      @attacher.validate
      assert_equal false, validation_passed
    end

    it "is aliased to #validate_extension" do
      @attacher.class.validate { validate_extension(["mp4"]) }
      @attacher.validate
      assert_equal ["extension must be one of: mp4"], @attacher.errors
    end
  end

  describe "#validate_extension_exclusion" do
    before do
      @attacher.attach(fakeio(filename: "video.mp4"))
    end

    it "adds an error when extension is in the blacklist" do
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
      @attacher.attach(fakeio(filename: nil))
      @attacher.class.validate { validate_extension_exclusion(["jpg"]) }
      @attacher.validate
      assert_equal 0, @attacher.errors.size
    end

    it "uses the default error message" do
      @attacher.class.validate { validate_extension_exclusion(["mp4"]) }
      @attacher.validate
      assert_equal ["extension must not be one of: mp4"], @attacher.errors
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
      @attacher.attach(fakeio(filename: "image.JPG"))
      @attacher.class.validate { validate_extension_exclusion ["jpg"] }
      @attacher.validate
      assert_equal 1, @attacher.errors.size
    end

    it "returns whether the validation succeeded" do
      validation_passed = nil

      @attacher.class.validate { validation_passed = validate_extension_exclusion(["jpg"]) }
      @attacher.validate
      assert_equal true, validation_passed

      @attacher.class.validate { validation_passed = validate_extension_exclusion(["mp4"]) }
      @attacher.validate
      assert_equal false, validation_passed
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
    @attacher.attach(fakeio("file"))
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
    @attacher.attach(fakeio("file", content_type: "image/gif"))
    assert_equal ["is too big", "is forbidden"], @attacher.errors
  end
end
