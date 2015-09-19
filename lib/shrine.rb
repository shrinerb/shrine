require "shrine/version"

require "securerandom"
require "json"

class Shrine
  class Error < StandardError; end

  class InvalidFile < Error
    def initialize(io, missing_methods)
      @io, @missing_methods = io, missing_methods
    end

    def message
      "#{@io.inspect} is not a valid IO object (it doesn't respond to #{missing_methods_string})"
    end

    private

    def missing_methods_string
      @missing_methods.map { |m, args| "`#{m}(#{args.join(", ")})`" }.join(", ")
    end
  end

  class Confirm < Error
    def message
      "Are you sure you want to delete all files from the storage? (confirm with `clear!(:confirm)`)"
    end
  end

  # Methods which an object has to respond to in order to be considered
  # an IO object.
  IO_METHODS = {
    :read   => [:length, :outbuf],
    :eof?   => [],
    :rewind => [],
    :size   => [],
    :close  => [],
  }

  class UploadedFile
    @shrine_class = ::Shrine
  end

  class Attachment < Module
    @shrine_class = ::Shrine
  end

  class Attacher
    @shrine_class = ::Shrine
  end

  @opts = {}
  @storages = {}

  module Plugins
    @plugins = {}

    # If the registered plugin already exists, use it.  Otherwise, require it
    # and return it.  This raises a LoadError if such a plugin doesn't exist,
    # or a Shrine::Error if it exists but it does not register itself
    # correctly.
    def self.load_plugin(name)
      unless plugin = @plugins[name]
        require "shrine/plugins/#{name}"
        raise Error, "plugin #{name} did not register itself correctly in Shrine::Plugins" unless plugin = @plugins[name]
      end
      plugin
    end

    # Register the given plugin with Shrine, so that it can be loaded using
    # #plugin with a symbol.  Should be used by plugin files. Example:
    #
    #   Shrine::Plugins.register_plugin(:plugin_name, PluginModule)
    def self.register_plugin(name, mod)
      @plugins[name] = mod
    end

    module Base
      module ClassMethods
        attr_reader :opts

        # When inheriting Shrine, copy the shared data into the subclass,
        # and setup the manager and proxy subclasses.
        def inherited(subclass)
          subclass.instance_variable_set(:@opts, opts.dup)
          subclass.opts.each do |key, value|
            if value.is_a?(Enumerable) && !value.frozen?
              subclass.opts[key] = value.dup
            end
          end
          subclass.instance_variable_set(:@storages, storages.dup)

          file_class = Class.new(self::UploadedFile)
          file_class.shrine_class = subclass
          subclass.const_set(:UploadedFile, file_class)

          attachment_class = Class.new(self::Attachment)
          attachment_class.shrine_class = subclass
          subclass.const_set(:Attachment, attachment_class)

          attacher_class = Class.new(self::Attacher)
          attacher_class.shrine_class = subclass
          subclass.const_set(:Attacher, attacher_class)
        end

        # Load a new plugin into the current class.  A plugin can be a module
        # which is used directly, or a symbol represented a registered plugin
        # which will be required and then used. Returns nil.
        #
        #   Shrine.plugin PluginModule
        #   Shrine.plugin :basic_authentication
        def plugin(plugin, *args, &block)
          plugin = Plugins.load_plugin(plugin) if plugin.is_a?(Symbol)
          plugin.load_dependencies(self, *args, &block) if plugin.respond_to?(:load_dependencies)
          include(plugin::InstanceMethods) if defined?(plugin::InstanceMethods)
          extend(plugin::ClassMethods) if defined?(plugin::ClassMethods)
          self::UploadedFile.include(plugin::FileMethods) if defined?(plugin::FileMethods)
          self::UploadedFile.extend(plugin::FileClassMethods) if defined?(plugin::FileClassMethods)
          self::Attachment.include(plugin::AttachmentMethods) if defined?(plugin::AttachmentMethods)
          self::Attachment.extend(plugin::AttachmentClassMethods) if defined?(plugin::AttachmentClassMethods)
          self::Attacher.include(plugin::AttacherMethods) if defined?(plugin::AttacherMethods)
          self::Attacher.extend(plugin::AttacherClassMethods) if defined?(plugin::AttacherClassMethods)
          plugin.configure(self, *args, &block) if plugin.respond_to?(:configure)
          nil
        end

        attr_accessor :storages

        def storage(name)
          storages.fetch(name.to_s)
        rescue KeyError
          raise Error, "#{self} doesn't have storage #{name.inspect}"
        end

        def cache=(storage)
          storages["cache"] = storage
        end

        def cache
          storages["cache"]
        end

        def store=(storage)
          storages["store"] = storage
        end

        def store
          storages["store"]
        end

        def attachment(*args)
          self::Attachment.new(*args)
        end
        alias [] attachment

        def validate(&block)
          if block
            @validate_block = block
          else
            @validate_block
          end
        end

        def io!(io)
          missing_methods = IO_METHODS.reject do |m, args|
            io.respond_to?(m) && (io.method(m).arity == args.count || io.method(m).arity == -1)
          end
          raise InvalidFile.new(io, missing_methods) if missing_methods.any?
        end

        def io?(io)
          IO_METHODS.all? { |m| io.respond_to?(m) }
        end
      end

      module InstanceMethods
        def initialize(storage_key)
          @storage_key = storage_key.to_s
          storage # ensure storage exists
        end

        attr_reader :storage_key

        def storage
          @storage ||= self.class.storage(storage_key)
        end

        def opts
          self.class.opts
        end

        def upload(io, context = {})
          _enforce_io(io)
          _upload(io, context)
        end

        def uploaded?(uploaded_file)
          uploaded_file.storage_key == storage_key
        end

        def generate_location(io, context)
          return context[:location] if context.key?(:location)

          original_filename = extract_filename(io)
          extension = File.extname(original_filename.to_s)
          basename = generate_uid(io)

          basename + extension
        end

        def extract_metadata(io, context)
          {
            "filename" => extract_filename(io),
            "size" => extract_size(io),
            "content_type" => extract_content_type(io),
          }
        end

        def extract_filename(io)
          if io.respond_to?(:original_filename)
            io.original_filename
          elsif io.respond_to?(:path)
            File.basename(io.path)
          end
        end

        def extract_content_type(io)
          if io.respond_to?(:content_type)
            io.content_type
          end
        end

        def extract_size(io)
          io.size
        end

        def default_url(*)
        end

        private

        def _upload(io, context)
          location = generate_location(io, context)
          metadata = extract_metadata(io, context)

          store(io, location)

          self.class::UploadedFile.new(
            "id"       => location,
            "storage"  => storage_key,
            "metadata" => metadata,
          )
        end

        def store(io, location)
          storage.upload(io, location)
        end

        def _enforce_io(io)
          self.class.io!(io)
        end

        def generate_uid(io)
          SecureRandom.uuid
        end
      end

      module AttachmentClassMethods
        attr_accessor :shrine_class

        def inspect
          "#{shrine_class.inspect}::Attachment"
        end
      end

      module AttachmentMethods
        def initialize(name, cache: :cache, store: :store)
          @name = name

          class_variable_set(:"@@#{name}_attacher_class", shrine_class::Attacher)

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}_attacher
              @#{name}_attacher ||= @@#{name}_attacher_class.new(
                self, #{name.inspect},
                cache: #{cache.inspect}, store: #{store.inspect}
              )
            end

            def #{name}=(value)
              #{name}_attacher.set(value)
            end

            def #{name}
              #{name}_attacher.get
            end

            def #{name}_url(*args)
              #{name}_attacher.url(*args)
            end
          RUBY
        end

        def inspect
          "#<#{self.class.inspect}(#{@name})>"
        end

        def shrine_class
          self.class.shrine_class
        end
      end

      module AttacherClassMethods
        attr_accessor :shrine_class

        def inspect
          "#{shrine_class.inspect}::Attacher"
        end
      end

      module AttacherMethods
        attr_reader :record, :name, :cache, :store, :errors

        def initialize(record, name, cache: :cache, store: :store)
          @record = record
          @name   = name
          @cache  = shrine_class.new(cache)
          @store  = shrine_class.new(store)
          @errors = []
        end

        def set(value)
          return if value == ""

          uploaded_file =
            if value.is_a?(String)
              uploaded_file(deserialize(value))
            elsif value.is_a?(Hash)
              uploaded_file(value)
            elsif value
              cache!(value)
            end

          @old_attachment = get
          _set(uploaded_file)
          validate!

          get
        end

        def get
          if data = read
            uploaded_file(data)
          end
        end

        def save
          if (cached_file = get) && !store.uploaded?(cached_file)
            stored_file = store!(cached_file)
            _set(stored_file)
          end

          delete!(@old_attachment) if @old_attachment
        end

        def destroy
          if uploaded_file = get
            delete!(uploaded_file)
          end
        end

        def url(*args)
          if uploaded_file = get
            uploaded_file.url
          else
            default_url(*args)
          end
        end

        def default_url(*)
          store.default_url(context)
        end

        def validate!
          errors.clear
          instance_exec(&validate_block) if validate_block && get
        end

        def shrine_class
          self.class.shrine_class
        end

        private

        def cache!(io)
          cache.upload(io, context)
        end

        def store!(io)
          store.upload(io, context)
        end

        def delete!(uploaded_file)
          uploaded_file.delete
        end

        def validate_block
          shrine_class.validate
        end

        def _set(uploaded_file)
          write(uploaded_file ? data(uploaded_file) : nil)
        end

        def write(data)
          value = data ? serialize(data) : nil
          record.send("#{name}_data=", value)
        end

        def read
          data = record.send("#{name}_data")
          data.is_a?(String) ? deserialize(data) : data
        end

        def uploaded_file(data)
          shrine_class::UploadedFile.new(data)
        end

        def data(uploaded_file)
          uploaded_file.data
        end

        def context
          {name: name.to_s, record: record}
        end

        def deserialize(string)
          JSON.load(string)
        end

        def serialize(object)
          JSON.dump(object)
        end
      end

      module FileClassMethods
        attr_accessor :shrine_class

        def inspect
          "#{shrine_class.inspect}::UploadedFile"
        end
      end

      module FileMethods
        attr_reader :data, :id, :storage_key, :metadata

        def initialize(data)
          @data        = data
          @id          = data.fetch("id")
          @storage_key = data.fetch("storage")
          @metadata    = data.fetch("metadata")

          storage # ensure storage exists
        end

        def original_filename
          metadata.fetch("filename")
        end

        def size
          metadata.fetch("size")
        end

        def content_type
          metadata.fetch("content_type")
        end

        def read(*args)
          io.read(*args)
        end

        def eof?
          io.eof?
        end

        def close
          io.close
        end

        def rewind
          @io = nil
        end

        def url
          storage.url(id)
        end

        def exists?
          storage.exists?(id)
        end

        def download
          storage.download(id)
        end

        def delete
          storage.delete(id)
        end

        def to_json(*args)
          data.to_json(*args)
        end

        def ==(other)
          other.is_a?(self.class) &&
          self.id == other.id &&
          self.storage_key == other.storage_key
        end
        alias eql? ==

        def hash
          [id, storage_key].hash
        end

        def storage
          @storage ||= shrine_class.storage(storage_key)
        end

        def shrine_class
          self.class.shrine_class
        end

        private

        def io
          @io ||= storage.open(id)
        end
      end
    end
  end

  extend Plugins::Base::ClassMethods
  plugin Plugins::Base
end
