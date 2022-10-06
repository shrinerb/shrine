require "test_helper"
require "shrine/plugins/entity"

describe Shrine::Plugins::Entity do
  before do
    @attacher = attacher { plugin :entity }
    @shrine   = @attacher.shrine_class

    @entity_class = entity_class(:file_data)
  end

  describe "Attachment" do
    describe ".<name>_attacher" do
      it "returns attacher instance" do
        @entity_class.include @shrine::Attachment.new(:file)

        assert_instance_of @shrine::Attacher, @entity_class.file_attacher
      end

      it "sets attacher name" do
        @entity_class.include @shrine::Attachment.new(:file)

        assert_equal :file, @entity_class.file_attacher.name
      end

      it "applies attachment options" do
        @entity_class.include @shrine::Attachment.new(:file, store: :other_store)

        assert_equal :other_store, @entity_class.file_attacher.store_key
      end

      it "accepts attacher options" do
        @entity_class.include @shrine::Attachment.new(:file, store: :other_store)

        assert_equal :store, @entity_class.file_attacher(store: :store).store_key
      end
    end

    describe "#<name>_attacher" do
      it "returns the attacher from the entity instance" do
        @entity_class.include @shrine::Attachment.new(:file)

        file     = @attacher.upload(fakeio)
        entity   = @entity_class.new(file_data: file.to_json)
        attacher = entity.file_attacher

        assert_instance_of @shrine::Attacher, attacher
        assert_equal entity,                  attacher.record
        assert_equal :file,                   attacher.name
        assert_equal file,                    attacher.file
      end

      it "forwards additional attacher options" do
        @entity_class.include @shrine::Attachment.new(:file)

        entity   = @entity_class.new
        attacher = entity.file_attacher(cache: :other_cache)

        assert_equal :other_cache, attacher.cache_key
      end

      it "forwards additional attachment options" do
        @entity_class.include @shrine::Attachment.new(:file, cache: :other_cache)

        entity   = @entity_class.new
        attacher = entity.file_attacher

        assert_equal :other_cache, attacher.cache_key
      end

      it "doesn't memoize the attacher" do
        @entity_class.include @shrine::Attachment.new(:file)

        entity = @entity_class.new
        entity.freeze

        refute_equal entity.file_attacher, entity.file_attacher
      end
    end

    describe "#<name>" do
      it "returns file if it's attached" do
        @entity_class.include @shrine::Attachment.new(:file)

        file   = @attacher.upload(fakeio)
        entity = @entity_class.new(file_data: file.to_json)

        assert_equal file, entity.file
      end

      it "returns nil when no file is attached" do
        @entity_class.include @shrine::Attachment.new(:file)

        entity = @entity_class.new

        assert_nil entity.file
      end

      it "doesn't accept arguments by default" do
        @entity_class.include @shrine::Attachment.new(:file)

        entity = @entity_class.new

        error = assert_raises(ArgumentError) { entity.file(:foo) }
        assert_equal "wrong number of arguments (given 1, expected 0)", error.message
        assert_includes error.backtrace[0], "shrine/plugins/entity.rb"
      end
    end

    describe "#<name>_url" do
      it "returns the attached file URL" do
        @entity_class.include @shrine::Attachment.new(:file)

        file   = @attacher.upload(fakeio)
        entity = @entity_class.new(file_data: file.to_json)

        assert_equal file.url, entity.file_url
      end

      it "returns nil when no file is attached" do
        @entity_class.include @shrine::Attachment.new(:file)

        entity = @entity_class.new

        assert_nil entity.file_url
      end

      it "forwards additional options" do
        @entity_class.include @shrine::Attachment.new(:file)

        file   = @attacher.upload(fakeio)
        entity = @entity_class.new(file_data: file.to_json)

        file.storage.expects(:url).with(file.id, foo: "bar")

        entity.file_url(foo: "bar")
      end
    end
  end

  describe "Attacher" do
    describe ".from_entity" do
      it "loads the file from an entity" do
        file   = @attacher.upload(fakeio)
        entity = @entity_class.new(file_data: file.to_json)

        attacher = @shrine::Attacher.from_entity(entity, :file)

        assert_equal file,   attacher.file
        assert_equal entity, attacher.record
        assert_equal :file,  attacher.name
      end

      it "forwards additional options to .new" do
        entity   = @entity_class.new
        attacher = @shrine::Attacher.from_entity(entity, :file, cache: :other_cache)

        assert_equal :other_cache, attacher.cache_key
      end
    end

    describe "#load_entity" do
      it "loads file from the data attribute" do
        file   = @attacher.upload(fakeio)
        entity = @entity_class.new(file_data: file.to_json)

        @attacher.load_entity(entity, :file)

        assert_equal file, @attacher.file
      end

      it "respects column serializer" do
        @shrine.plugin :column, serializer: nil

        file   = @attacher.upload(fakeio)
        entity = @entity_class.new(file_data: file.data)

        @attacher = @shrine::Attacher.new
        @attacher.load_entity(entity, :file)

        assert_equal file, @attacher.file
      end

      it "clears file when data attribute is nil" do
        entity = @entity_class.new

        @attacher.attach(fakeio)
        @attacher.load_entity(entity, :file)

        assert_nil @attacher.file
      end
    end

    describe "#set_entity" do
      it "saves record and name" do
        entity = @entity_class.new

        @attacher.set_entity(entity, :file)

        assert_equal entity, @attacher.record
        assert_equal :file,  @attacher.name
      end

      it "coerces string name into a symbol" do
        entity = @entity_class.new

        @attacher.set_entity(entity, "file")

        assert_equal :file, @attacher.name
      end

      it "merges record and name into context" do
        entity = @entity_class.new

        @attacher.set_entity(entity, :file)

        assert_equal Hash[record: entity, name: :file], @attacher.context
      end
    end

    describe "#reload" do
      it "loads entity file data" do
        @attacher.load_entity(@entity_class.new, :file)
        @attacher.attach(fakeio)
        @attacher.reload

        assert_nil @attacher.file
      end

      it "resets dirty tracking" do
        @attacher.load_entity(@entity_class.new, :file)
        @attacher.attach(fakeio)
        @attacher.reload

        refute @attacher.changed?
      end
    end

    describe "#read" do
      it "loads entity file data" do
        @attacher.load_entity(@entity_class.new, :file)
        @attacher.attach(fakeio)
        @attacher.read

        assert_nil @attacher.file
      end
    end

    describe "#column_values" do
      it "returns column values with an attached file" do
        @attacher.load_entity(@entity_class.new, :file)
        @attacher.attach(fakeio)

        assert_equal Hash[file_data: @attacher.file.to_json], @attacher.column_values
      end

      it "returns column values with no attached file" do
        @attacher.load_entity(@entity_class.new, :file)

        assert_equal Hash[file_data: nil], @attacher.column_values
      end

      it "respects column serializer" do
        @shrine.plugin :column, serializer: nil

        @attacher = @shrine::Attacher.new
        @attacher.load_entity(@entity_class.new, :file)
        @attacher.attach(fakeio)

        assert_equal Hash[file_data: @attacher.file.data], @attacher.column_values
      end
    end

    describe "#attribute" do
      it "returns the data attribute name" do
        @attacher.load_entity(@entity_class.new, :file)

        assert_equal :file_data, @attacher.attribute
      end

      it "returns nil when name is not set" do
        assert_nil @attacher.attribute
      end
    end
  end
end
