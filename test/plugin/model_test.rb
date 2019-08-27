require "test_helper"
require "shrine/plugins/model"

describe Shrine::Plugins::Model do
  before do
    @attacher = attacher { plugin :model }
    @shrine   = @attacher.shrine_class

    @model_class = model_class(:file_data)
  end

  describe "Attachment" do
    describe "#<name>_attacher" do
      it "returns a model attacher" do
        @model_class.include @shrine::Attachment.new(:file)

        model    = @model_class.new
        attacher = model.file_attacher

        attacher.attach(fakeio)
        assert_equal attacher.file.to_json, model.file_data
      end

      it "memoizes the attacher instance" do
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new

        assert_equal model.file_attacher, model.file_attacher
      end

      it "reloads the attacher when options are passed in" do
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file_attacher # memoize the attacher

        attacher = model.file_attacher(cache: :other_cache)

        assert_equal :other_cache, attacher.cache_key
        assert_equal attacher,     model.file_attacher
      end

      it "forwards additional attachment options" do
        @model_class.include @shrine::Attachment.new(:file, cache: :other_cache)

        model    = @model_class.new
        attacher = model.file_attacher

        assert_equal :other_cache, attacher.cache_key
      end

      it "doesn't memoize attacher for entity attachments" do
        @model_class.include @shrine::Attachment.new(:file, type: :entity)

        model = @model_class.new

        refute_equal model.file_attacher, model.file_attacher
      end

      it "returns entity attacher for entity attachments" do
        @model_class.include @shrine::Attachment.new(:file, type: :entity)

        model = @model_class.new
        model.file_attacher.attach(fakeio)

        assert_nil model.file_data
      end
    end

    describe "#<name>=" do
      it "assigns file by default" do
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file = fakeio

        assert_equal model.file.to_json, model.file_data
        assert_equal :cache, model.file.storage_key
      end

      it "attaches file when caching is disabled" do
        @shrine.plugin :model, cache: false
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file = fakeio

        assert_equal model.file.to_json, model.file_data
        assert_equal :store, model.file.storage_key
      end

      it "isn't defined on entity attachments" do
        @model_class.include @shrine::Attachment.new(:file, type: :entity)

        refute @model_class.method_defined?(:file=)
      end
    end

    describe "#<name>_changed?" do
      it "returns true if attachment has changed" do
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file = fakeio

        assert_equal true, model.file_changed?
      end

      it "returns false if attachment has not changed" do
        @model_class.include @shrine::Attachment.new(:file)

        file  = @attacher.upload(fakeio)
        model = @model_class.new(file_data: file.to_json)

        assert_equal false, model.file_changed?
      end

      it "isn't defined on entity attachments" do
        @model_class.include @shrine::Attachment.new(:file, type: :entity)

        refute @model_class.method_defined?(:file_changed?)
      end
    end

    describe "#initialize_copy" do
      it "duplicates the attacher" do
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file_attacher.attach(fakeio)

        model_copy = model.dup

        assert model_copy.file_attacher.changed? # retains any state
        refute_equal model.file_attacher, model_copy.file_attacher
      end

      it "handles attacher not being loaded" do
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.dup
      end

      it "isn't overridden on entity attachments" do
        @model_class.include @shrine::Attachment.new(:file, type: :entity)

        assert_equal Kernel, @model_class.instance_method(:initialize_copy).owner
      end

      it "keeps private visibility" do
        @model_class.include @shrine::Attachment.new(:file)

        assert_includes @model_class.private_instance_methods, :initialize_copy
      end
    end

    it "includes other entity methods" do
      @model_class.include @shrine::Attachment.new(:file)

      file  = @attacher.upload(fakeio)
      model = @model_class.new(file_data: file.to_json)

      assert_equal file,     model.file
      assert_equal file.url, model.file_url
    end
  end

  describe "Attacher" do
    describe ".from_model" do
      it "loads the file from a model" do
        file  = @attacher.upload(fakeio)
        model = @model_class.new(file_data: file.to_json)

        attacher = @shrine::Attacher.from_model(model, :file)

        assert_equal file,  attacher.file
        assert_equal model, attacher.record
        assert_equal :file, attacher.name
      end

      it "creates a model attacher" do
        model = @model_class.new

        attacher = @shrine::Attacher.from_model(model, :file)
        attacher.attach(fakeio)

        assert_equal attacher.file.to_json, model.file_data
      end

      it "forwards additional options to .new" do
        model    = @model_class.new
        attacher = @shrine::Attacher.from_model(model, :file, cache: :other_cache)

        assert_equal :other_cache, attacher.cache_key
      end
    end

    describe "#load_model" do
      it "loads file from the data attribute" do
        file  = @attacher.upload(fakeio)
        model = @model_class.new(file_data: file.to_json)

        @attacher.load_model(model, :file)

        assert_equal file, @attacher.file
      end

      it "makes the attacher model type" do
        model = @model_class.new

        @attacher.load_model(model, :file)
        @attacher.attach(fakeio)

        assert_equal @attacher.file.to_json, model.file_data
      end
    end

    describe "#set_model" do
      it "sets record and name" do
        model = @model_class.new

        @attacher.set_model(model, :file)

        assert_equal model, @attacher.record
        assert_equal :file, @attacher.name
      end

      it "makes attacher model type" do
        model = @model_class.new

        @attacher.set_model(model, :file)
        @attacher.attach(fakeio)

        assert_equal @attacher.file.to_json, model.file_data
      end
    end

    describe "#model_assign" do
      it "assigns the file by default" do
        @attacher.load_model(@model_class.new, :file)
        @attacher.model_assign(fakeio, location: "foo")

        assert_equal :cache, @attacher.file.storage_key
        assert_equal "foo",  @attacher.file.id
      end

      it "attaches the file when caching is disabled globally" do
        @shrine.plugin :model, cache: false

        @attacher = @shrine::Attacher.new
        @attacher.load_model(@model_class.new, :file)
        @attacher.model_assign(fakeio, location: "foo")

        assert_equal :store, @attacher.file.storage_key
        assert_equal "foo",  @attacher.file.id
      end

      it "attaches the file when caching is disabled for attacher" do
        @attacher = @shrine::Attacher.new(model_cache: false)
        @attacher.load_model(@model_class.new, :file)
        @attacher.model_assign(fakeio, location: "foo")

        assert_equal :store, @attacher.file.storage_key
        assert_equal "foo",  @attacher.file.id
      end
    end

    describe "#set" do
      it "writes to the model attribute" do
        model = @model_class.new

        @attacher.load_model(model, :file)
        @attacher.set @attacher.upload(fakeio)

        assert_equal @attacher.file.to_json, model.file_data
      end

      it "doesn't write when attacher is entity" do
        model = @model_class.new

        @attacher.load_entity(model, :file)
        @attacher.set @attacher.upload(fakeio)

        assert_nil model.file_data
      end

      it "still returns set file" do
        file = @attacher.upload(fakeio)
        assert_equal file, @attacher.set(file)
      end
    end

    describe "#write" do
      it "writes to the model attribute" do
        model = @model_class.new

        @attacher.load_model(model, :file)
        @attacher.file = @attacher.upload(fakeio)
        @attacher.write

        assert_equal @attacher.file.to_json, model.file_data
      end
    end
  end
end
