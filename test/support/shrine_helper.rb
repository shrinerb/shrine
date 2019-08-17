require "shrine/storage/memory"
require "dry-initializer"

module ShrineHelper
  def shrine(&block)
    uploader_class = Class.new(Shrine)
    uploader_class.storages[:cache]       = Shrine::Storage::Memory.new
    uploader_class.storages[:other_cache] = Shrine::Storage::Memory.new
    uploader_class.storages[:store]       = Shrine::Storage::Memory.new
    uploader_class.storages[:other_store] = Shrine::Storage::Memory.new
    uploader_class.class_eval(&block) if block
    uploader_class
  end

  def uploader(storage_key = :store, &block)
    uploader_class = shrine(&block)
    uploader_class.new(storage_key)
  end

  def attacher(**options, &block)
    shrine = shrine(&block)
    shrine::Attacher.new(**options)
  end

  def model_class(*attributes)
    klass = entity_class(*attributes)
    klass.send(:attr_writer, *attributes)
    klass
  end

  def entity_class(*attributes)
    klass = Class.new
    klass.extend Dry::Initializer
    attributes.each do |attribute|
      klass.option attribute, optional: true
    end
    klass
  end

  def entity(attributes)
    entity_class = entity_class(*attributes.keys)
    entity_class.new(attributes)
  end

  def model(attributes)
    model_class = model_class(*attributes.keys)
    model_class.new(attributes)
  end
end

Minitest::Test.include ShrineHelper
