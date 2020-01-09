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
      it "runs validation by default" do
        @attacher.class.validate { errors << "error" }
        cached_file = @attacher.upload(fakeio, :cache)
        @attacher.attach_cached(cached_file.data)
        assert_equal ["error"], @attacher.errors
      end

      it "runs validation only once for raw IO" do
        count = 0
        @attacher.class.validate { count += 1 }
        @attacher.attach_cached(fakeio)
        assert_equal 1, count
      end

      it "skips validation when :validate is false" do
        @attacher.errors << "error"
        @attacher.class.validate { errors << "new_error" }
        @attacher.attach_cached(fakeio, validate: false)
        assert_equal [], @attacher.errors
      end

      it "runs validation when :validate is true" do
        @attacher.class.validate { errors << "error" }
        @attacher.attach_cached(fakeio, validate: true)
        assert_equal ["error"], @attacher.errors
      end

      it "forwards :validate options to validation block" do
        validate_options = nil
        @attacher.class.validate { |**options| validate_options = options }
        @attacher.attach_cached(fakeio, validate: { foo: "bar" })
        assert_equal Hash[foo: "bar"], validate_options
      end

      it "still returns attached file" do
        assert_instance_of @shrine::UploadedFile, @attacher.attach_cached(fakeio)
      end
    end

    describe "#attach" do
      it "runs validation by default" do
        @attacher.class.validate { errors << "error" }
        @attacher.attach(fakeio)
        assert_equal ["error"], @attacher.errors
      end

      it "skips validation when :validate is false" do
        @attacher.errors << "error"
        @attacher.class.validate { errors << "new_error" }
        @attacher.attach(fakeio, validate: false)
        assert_equal [], @attacher.errors
      end

      it "runs validation when :validate is true" do
        @attacher.class.validate { errors << "error" }
        @attacher.attach(fakeio, validate: true)
        assert_equal ["error"], @attacher.errors
      end

      it "forwards :validate options to validation block" do
        validate_options = nil
        @attacher.class.validate { |**options| validate_options = options }
        @attacher.attach(fakeio, validate: { foo: "bar" })
        assert_equal Hash[foo: "bar"], validate_options
      end

      it "doesn't forward :validate option to the uploader" do
        io = fakeio
        empty_hash = {}
        @shrine.expects(:upload).with(io, :store, **empty_hash)
        @attacher.attach(io, validate: { foo: "bar" })
      end

      it "still returns attached file" do
        assert_instance_of @shrine::UploadedFile, @attacher.attach(fakeio)
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

    describe "with model plugin" do
      before do
        @shrine.plugin :model

        model_class = model_class(:file_data)
        model_class.include @shrine::Attachment.new(:file)

        @model = model_class.new
      end

      it "runs validation with caching on" do
        @shrine::Attacher.validate { errors << "error" }

        @model.file = fakeio

        assert_equal ["error"], @model.file_attacher.errors
      end

      it "runs validation with caching off" do
        @shrine.plugin :model, cache: false
        @shrine::Attacher.validate { errors << "error" }

        @model.file = fakeio

        assert_equal ["error"], @model.file_attacher.errors
      end
    end
  end
end
