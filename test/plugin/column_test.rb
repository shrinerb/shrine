require "test_helper"
require "shrine/plugins/column"
require "delegate"
require "stringio"

describe Shrine::Plugins::Column do
  before do
    @attacher = attacher { plugin :column }
    @shrine   = @attacher.shrine_class
  end

  describe ".from_column" do
    it "loads file from column data" do
      file     = @attacher.upload(fakeio)
      attacher = @shrine::Attacher.from_column(file.to_json)

      assert_equal file, attacher.file
    end

    it "forwards additional options to .new" do
      attacher = @shrine::Attacher.from_column(nil, cache: :other_cache)

      assert_equal :other_cache, attacher.cache_key
    end
  end

  describe "#initialize" do
    it "accepts a serializer" do
      attacher = @shrine::Attacher.new(column_serializer: :my_serializer)

      assert_equal :my_serializer, attacher.column_serializer
    end

    it "accepts nil serializer" do
      attacher = @shrine::Attacher.new(column_serializer: nil)

      assert_nil attacher.column_serializer
    end

    it "uses plugin serializer as default" do
      @shrine.plugin :column, serializer: RubySerializer
      assert_equal RubySerializer, @shrine::Attacher.new.column_serializer

      @shrine.plugin :column, serializer: nil
      assert_nil @shrine::Attacher.new.column_serializer
    end
  end

  describe "#load_column" do
    it "loads file from serialized file data" do
      file = @attacher.upload(fakeio)
      @attacher.load_column(file.to_json)

      assert_equal file, @attacher.file
    end

    it "clears file when nil is given" do
      @attacher.attach(fakeio)
      @attacher.load_column(nil)

      assert_nil @attacher.file
    end

    it "clears file when empty string is given" do
      @attacher.attach(fakeio)
      @attacher.load_column("")

      assert_nil @attacher.file
    end

    it "handles hashes" do
      file = @attacher.attach(fakeio)
      @attacher.load_column(file.data)

      assert_equal file, @attacher.file
    end

    it "uses custom serializer" do
      @attacher = @shrine::Attacher.new(column_serializer: RubySerializer)

      file = @attacher.upload(fakeio)
      @attacher.load_column(file.data.to_s)

      assert_equal file, @attacher.file
    end

    it "skips serialization if serializer is nil" do
      @attacher = @shrine::Attacher.new(column_serializer: nil)

      file = @attacher.upload(fakeio)
      @attacher.load_column(file.data)

      assert_equal file, @attacher.file
    end

    it "works with hash-like objects" do
      @attacher = @shrine::Attacher.new(column_serializer: nil)

      file = @attacher.upload(fakeio)
      hash = DelegateClass(Hash).new(file.data)

      @attacher.load_column(hash)

      assert_equal file, @attacher.file
    end
  end

  describe "#column_data" do
    it "returns serialized file data" do
      @attacher.attach(fakeio)

      assert_equal @attacher.file.to_json, @attacher.column_data
    end

    it "returns nil when no file is attached" do
      assert_nil @attacher.column_data
    end

    it "uses custom serializer" do
      @attacher = @shrine::Attacher.new(column_serializer: RubySerializer)
      @attacher.attach(fakeio)

      assert_equal @attacher.file.data.to_s, @attacher.column_data
    end

    it "skips serialization if serializer is nil" do
      @attacher = @shrine::Attacher.new(column_serializer: nil)
      @attacher.attach(fakeio)

      assert_equal @attacher.file.data, @attacher.column_data
    end
  end

  it "allows serializing into custom objects" do
    custom_serializer = Class.new do
      def self.dump(data)
        StringIO.new(data.to_json)
      end

      def self.load(stringio)
        JSON.parse(stringio.string)
      end
    end

    @attacher = @shrine::Attacher.new(column_serializer: custom_serializer)

    file = @attacher.attach(fakeio)

    assert_instance_of StringIO, @attacher.column_data

    @attacher.load_column(@attacher.column_data)

    assert_equal file, @attacher.file
  end
end
