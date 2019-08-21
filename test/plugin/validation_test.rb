require "test_helper"
require "shrine/plugins/validation"

describe Shrine::Plugins::Validation do
  before do
    @attacher = attacher { plugin :validation }
    @shrine   = @attacher.shrine_class
  end

  describe "Attacher" do
    describe ".validate" do
      it "is evaluated in the context of the attacher" do
        this = nil
        @attacher.class.validate { this = self }
        @attacher.attach(fakeio)

        assert_equal @attacher, this
      end

      it "supports validation inheritance" do
        @attacher.class.validate { errors << "superclass" }

        shrine   = Class.new(@shrine)
        attacher = shrine::Attacher.new
        attacher.class.validate { super(); errors << "subclass" }

        attacher.file = @attacher.upload(fakeio)
        attacher.validate

        assert_equal ["superclass", "subclass"], attacher.errors
      end

      it "keeps the #_validate method visibility" do
        assert_includes @attacher.private_methods, :_validate
        @attacher.class.validate { errors << "error" }
        assert_includes @attacher.private_methods, :_validate
      end
    end

    describe "#initialize" do
      it "sets #errors to empty array" do
        assert_equal [], @attacher.errors
      end
    end

    describe "#attach_cached" do
      it "forwards :validate option to validation block" do
        validate_options = nil
        @attacher.class.validate { |**options| validate_options = options }
        cached_file = @shrine.upload(fakeio, :cache)
        @attacher.attach_cached(cached_file.data, validate: { foo: "bar" })
        assert_equal Hash[foo: "bar"], validate_options
      end
    end

    describe "#attach" do
      it "forwards options to validation" do
        validate_options = nil
        @attacher.class.validate { |**options| validate_options = options }
        @attacher.attach(fakeio, validate: { foo: "bar" })
        assert_equal Hash[foo: "bar"], validate_options
      end

      it "doesn't forward :validate option to uploader" do
        io = fakeio
        @shrine.expects(:upload).with(io, :store, {})
        @attacher.attach(io, validate: { foo: "bar" })
      end
    end

    describe "#change" do
      it "runs validations" do
        @attacher.class.validate { errors << "error" }
        @attacher.change @attacher.upload(fakeio)
        assert_equal ["error"], @attacher.errors
      end

      it "fowards :validate option to validation block" do
        validate_options = nil
        @attacher.class.validate { |**options| validate_options = options }
        file = @attacher.upload(fakeio)
        @attacher.change(file, validate: { foo: "bar" })
        assert_equal Hash[foo: "bar"], validate_options
      end

      it "skips validation when :validate is set to false" do
        @attacher.class.validate { errors << "error" }
        file = @attacher.upload(fakeio)
        @attacher.change(file, validate: false)
        assert_equal [], @attacher.errors
      end

      it "runs validation when :validate is set to true" do
        @attacher.class.validate { errors << "error" }
        file = @attacher.upload(fakeio)
        @attacher.change(file, validate: true)
        assert_equal ["error"], @attacher.errors
      end

      it "still returns changed file" do
        file = @attacher.upload(fakeio)
        assert_equal file, @attacher.change(file)
      end
    end

    describe "#validate" do
      it "runs validations" do
        @attacher.file = @attacher.upload(fakeio)
        @attacher.class.validate { errors << "error" }
        @attacher.validate
        assert_equal ["error"], @attacher.errors
      end

      it "clears previous errors" do
        @attacher.file = @attacher.upload(fakeio)
        @attacher.errors << "previous_error"
        @attacher.class.validate { errors << "new_error" }
        @attacher.validate
        assert_equal ["new_error"], @attacher.errors
      end

      it "doesn't run validations if no file is attached" do
        @attacher.class.validate { errors << "error" }
        @attacher.validate
        assert_equal [], @attacher.errors
      end

      it "clears previous errors if no file is attached" do
        @attacher.errors << "error"
        @attacher.validate
        assert_equal [], @attacher.errors
      end

      it "fowards options to the validation block" do
        validate_options = nil
        @attacher.class.validate { |**options| validate_options = options }
        @attacher.file = @attacher.upload(fakeio)
        @attacher.validate(foo: "bar")
        assert_equal Hash[foo: "bar"], validate_options
      end
    end
  end
end
