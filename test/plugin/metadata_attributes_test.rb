require "test_helper"
require "shrine/plugins/metadata_attributes"

describe Shrine::Plugins::MetadataAttributes do
  before do
    @attacher = attacher { plugin :metadata_attributes }
    @shrine   = @attacher.shrine_class

    @entity_class = entity_class(:file_data)
  end

  describe "Attacher" do
    describe "#column_values" do
      it "returns metadata attributes" do
        @attacher.class.metadata_attributes size: :size, mime_type: :type

        @entity_class.option :file_size, optional: true
        @entity_class.option :file_type, optional: true

        io     = fakeio("file", content_type: "text/plain")
        file   = @shrine.upload(io, :store)
        entity = @entity_class.new(file_data: file.to_json)

        @attacher.load_entity(entity, :file)

        assert_equal Hash[
          file_data: file.to_json,
          file_size: 4,
          file_type: "text/plain",
        ], @attacher.column_values
      end

      it "allows specifying full record attribute name" do
        @attacher.class.metadata_attributes filename: "original_filename"

        @entity_class.option :original_filename, optional: true

        io     = fakeio("file", filename: "nature.jpg")
        file   = @shrine.upload(io, :store)
        entity = @entity_class.new(file_data: file.to_json)

        @attacher.load_entity(entity, :file)

        assert_equal Hash[
          file_data:         file.to_json,
          original_filename: "nature.jpg",
        ], @attacher.column_values
      end

      it "skips attributes that are not defined" do
        @attacher.class.metadata_attributes size: :size, mime_type: :type

        io     = fakeio("file", content_type: "text/plain")
        file   = @shrine.upload(io, :store)
        entity = @entity_class.new(file_data: file.to_json)

        @attacher.load_entity(entity, :file)

        assert_equal Hash[file_data: file.to_json], @attacher.column_values
      end

      it "works with metadata attributes defined when loading the plugin" do
        @shrine.plugin :metadata_attributes, size: :size, mime_type: :type

        @entity_class.option :file_size, optional: true
        @entity_class.option :file_type, optional: true

        io     = fakeio("file", content_type: "text/plain")
        file   = @shrine.upload(io, :store)
        entity = @entity_class.new(file_data: file.to_json)

        @attacher.load_entity(entity, :file)

        assert_equal Hash[
          file_data: file.to_json,
          file_size: file.size,
          file_type: file.mime_type,
        ], @attacher.column_values
      end
    end
  end

  it "integrates with model plugin" do
    @shrine.plugin :model
    @attacher.class.metadata_attributes size: :size, mime_type: :type

    model_class = model_class(:file_data)
    model_class.send(:attr_accessor, :file_size)
    model_class.send(:attr_accessor, :file_type)

    model = model_class.new

    @attacher.load_model(model, :file)
    @attacher.attach(fakeio("file", content_type: "text/plain"))

    assert_equal @attacher.file.to_json, model.file_data
    assert_equal 4,                      model.file_size
    assert_equal "text/plain",           model.file_type
  end

  it "merges mappings when loading the plugin" do
    @shrine.plugin :metadata_attributes, size: :size
    @shrine.plugin :metadata_attributes, mime_type: :type

    @entity_class.option :file_size, optional: true
    @entity_class.option :file_type, optional: true

    io     = fakeio("file", content_type: "text/plain")
    file   = @shrine.upload(io, :store)
    entity = @entity_class.new(file_data: file.to_json)

    @attacher.load_entity(entity, :file)

    assert_equal Hash[
      file_data: file.to_json,
      file_size: 4,
      file_type: "text/plain",
    ], @attacher.column_values
  end
end
