require "shrine/storage/memory"

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
    klass.attr_writer *attributes
    klass
  end

  def entity_class(*attributes)
    klass = Class.new(Struct)
    klass.attr_reader *attributes
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

  class Struct
    # These are private on Ruby 2.4 and older, so we make them public.
    def self.attr_reader(*names) super(*names) end
    def self.attr_writer(*names) super(*names) end

    def initialize(attributes = {})
      attributes.each do |name, value|
        instance_variable_set(:"@#{name}", value)
      end
    end
  end
end

Minitest::Test.include ShrineHelper
