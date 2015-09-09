require "uploadie/version"

require "securerandom"
require "json"

class Uploadie
  class Error < StandardError; end

  class InvalidFile < Error; end

  class Confirm < Error
    def message
      "Are you sure you want to delete all files from the storage? \
      (confirm with `clear!(:confirm)`)"
    end
  end

  class UploadedFile
    @uploadie_class = ::Uploadie
  end

  class Attachment < Module
    @uploadie_class = ::Uploadie
  end

  class Attacher
    @uploadie_class = ::Uploadie
  end

  @opts = {}
  @storages = {}

  module Plugins
    @plugins = {}

    # If the registered plugin already exists, use it.  Otherwise, require it
    # and return it.  This raises a LoadError if such a plugin doesn't exist,
    # or a Uploadie::Error if it exists but it does not register itself
    # correctly.
    def self.load_plugin(name)
      unless plugin = @plugins[name]
        require "uploadie/plugins/#{name}"
        raise Error, "plugin #{name} did not register itself correctly in Uploadie::Plugins" unless plugin = @plugins[name]
      end
      plugin
    end

    # Register the given plugin with Uploadie, so that it can be loaded using
    # #plugin with a symbol.  Should be used by plugin files. Example:
    #
    #   Uploadie::Plugins.register_plugin(:plugin_name, PluginModule)
    def self.register_plugin(name, mod)
      @plugins[name] = mod
    end

    module Base
      module ClassMethods
        attr_reader :opts

        # When inheriting Uploadie, copy the shared data into the subclass,
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
          file_class.uploadie_class = subclass
          subclass.const_set(:UploadedFile, file_class)

          attachment_class = Class.new(self::Attachment)
          attachment_class.uploadie_class = subclass
          subclass.const_set(:Attachment, attachment_class)

          attacher_class = Class.new(self::Attacher)
          attacher_class.uploadie_class = subclass
          subclass.const_set(:Attacher, attacher_class)
        end

        # Load a new plugin into the current class.  A plugin can be a module
        # which is used directly, or a symbol represented a registered plugin
        # which will be required and then used. Returns nil.
        #
        #   Uploadie.plugin PluginModule
        #   Uploadie.plugin :basic_authentication
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

        def cache=(storage)
          storages[:cache] = storage
        end

        def cache
          storages[:cache]
        end

        def store=(storage)
          storages[:store] = storage
        end

        def store
          storages[:store]
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
      end

      module InstanceMethods
        # Methods which an object has to respond to in order to be considered
        # an IO object.
        IO_METHODS = [:read, :eof?, :rewind, :size, :close].freeze

        def initialize(storage_key)
          @storage_key = storage_key
        end

        attr_reader :storage_key

        def storage
          @storage ||= self.class.storages.fetch(storage_key)
        end

        def opts
          self.class.opts
        end

        def upload(io, context = {})
          _upload(io, context)
        end

        def store(io, context = {})
          _enforce_io(io)
          _store(io, context)
        end

        def generate_location(io, context)
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

        def io?(io)
          IO_METHODS.all? { |m| io.respond_to?(m) }
        end

        private

        def _upload(io, context)
          store(io, context)
        end

        def _store(io, context)
          location = generate_location(io, context)
          metadata = extract_metadata(io, context)

          _put(io, location)

          self.class::UploadedFile.new(
            "id"       => location,
            "storage"  => storage_key.to_s,
            "metadata" => metadata,
          )
        end

        def _put(io, location)
          storage.upload(io, location)
        end

        def _enforce_io(io)
          IO_METHODS.each do |m|
            if not io.respond_to?(m)
              raise InvalidFile, "#{io.inspect} does not respond to `#{m}`"
            end
          end
        end

        def generate_uid(io)
          SecureRandom.uuid
        end
      end

      module AttachmentClassMethods
        attr_accessor :uploadie_class

        def inspect
          "#{uploadie_class.inspect}::Attachment"
        end
      end

      module AttachmentMethods
        def initialize(name, cache: :cache, store: :store)
          @name = name

          class_variable_set(:"@@#{name}_attacher_class", uploadie_class::Attacher)

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

        def uploadie_class
          self.class.uploadie_class
        end
      end

      module AttacherClassMethods
        attr_accessor :uploadie_class

        def inspect
          "#{uploadie_class.inspect}::Attacher"
        end
      end

      module AttacherMethods
        attr_reader :record, :name, :cache, :store, :errors

        def initialize(record, name, cache: :cache, store: :store)
          @record = record
          @name   = name
          @cache  = uploadie_class.new(cache)
          @store  = uploadie_class.new(store)
          @errors = []
        end

        def set(value)
          uploaded_file = value
          uploaded_file = cache!(value) unless value.nil? || uploaded?(value)
          @old_attachment = get
          _set(uploaded_file)
        end

        def get
          if data = read
            uploaded_file(data)
          end
        end

        def commit!
          uploaded_file = get

          if uploaded_file && !stored?(uploaded_file)
            stored_file = store!(uploaded_file)
            _set(stored_file)
          end

          delete!(@old_attachment) if @old_attachment
        end

        def url(*args)
          if uploaded_file = get
            uploaded_file.url
          else
            default_url(*args)
          end
        end

        def default_url(*)
          store.default_url(name: name, record: record)
        end

        def valid?
          validate
          errors.empty?
        end

        def validate
          errors.clear
          instance_exec(&uploadie_class.validate) if uploadie_class.validate
        end

        def uploadie_class
          self.class.uploadie_class
        end

        private

        def cache!(io)
          cache.upload(io, name: name, record: record)
        end

        def store!(io)
          store.upload(io, name: name, record: record)
        end

        def delete!(uploaded_file)
          uploaded_file.delete
        end

        def _set(uploaded_file)
          write(uploaded_file ? data(uploaded_file) : nil)
          uploaded_file
        end

        def uploaded?(object)
          object.is_a?(UploadedFile)
        end

        def cached?(uploaded_file)
          uploaded_file.storage_key == cache.storage_key
        end

        def stored?(uploaded_file)
          uploaded_file.storage_key == store.storage_key
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
          uploadie_class::UploadedFile.new(data)
        end

        def data(uploaded_file)
          uploaded_file.data
        end

        def deserialize(string)
          JSON.load(string)
        end

        def serialize(object)
          JSON.dump(object)
        end
      end

      module FileClassMethods
        attr_accessor :uploadie_class

        def inspect
          "#{uploadie_class.inspect}::UploadedFile"
        end
      end

      module FileMethods
        attr_reader :data, :id, :storage_key, :metadata

        def initialize(data)
          @data        = data
          @id          = data.fetch("id")
          @storage_key = data.fetch("storage").to_sym
          @metadata    = data.fetch("metadata")

          storage # ensure that error is raised if storage key doesn't exist
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

        def ==(other)
          other.is_a?(self.class) &&
          self.id == other.id &&
          self.storage_key == other.storage_key
        end

        def uploadie_class
          self.class.uploadie_class
        end

        private

        def io
          @io ||= storage.open(id)
        end

        def storage
          @storage ||= uploadie_class.storages.fetch(storage_key)
        end
      end
    end
  end

  extend Plugins::Base::ClassMethods
  plugin Plugins::Base
end
