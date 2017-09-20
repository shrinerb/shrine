require "shrine/version"

require "securerandom"
require "json"
require "tempfile"

class Shrine
  # A generic exception used by Shrine.
  class Error < StandardError; end

  # Raised when a file is not a valid IO.
  class InvalidFile < Error
    def initialize(io, missing_methods)
      @io, @missing_methods = io, missing_methods
    end

    def message
      "#{@io.inspect} is not a valid IO object (it doesn't respond to #{missing_methods_string})"
    end

    private

    def missing_methods_string
      @missing_methods.map { |m, args| "##{m}" }.join(", ")
    end
  end

  # Methods which an object has to respond to in order to be considered
  # an IO object, along with their arguments.
  IO_METHODS = {
    :read   => [:length, :outbuf],
    :eof?   => [],
    :rewind => [],
    :size   => [],
    :close  => [],
  }

  # Core class that represents a file uploaded to a storage. The instance
  # methods for this class are added by Shrine::Plugins::Base::FileMethods, the
  # class methods are added by Shrine::Plugins::Base::FileClassMethods.
  class UploadedFile
    @shrine_class = ::Shrine
  end

  # Core class which creates attachment modules for specified attribute names
  # that are included into model classes. The instance methods for this class
  # are added by Shrine::Plugins::Base::AttachmentMethods, the class methods
  # are added by Shrine::Plugins::Base::AttachmentClassMethods.
  class Attachment < Module
    @shrine_class = ::Shrine
  end

  # Core class which handles attaching files to model instances. The instance
  # methods for this class are added by Shrine::Plugins::Base::AttacherMethods,
  # the class methods are added by Shrine::Plugins::Base::AttacherClassMethods.
  class Attacher
    @shrine_class = ::Shrine
  end

  @opts = {}
  @storages = {}

  # Module in which all Shrine plugins should be stored. Also contains logic
  # for registering and loading plugins.
  module Plugins
    @plugins = {}

    # If the registered plugin already exists, use it. Otherwise, require it
    # and return it. This raises a LoadError if such a plugin doesn't exist,
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
    # `Shrine.plugin` with a symbol. Should be used by plugin files. Example:
    #
    #     Shrine::Plugins.register_plugin(:plugin_name, PluginModule)
    def self.register_plugin(name, mod)
      @plugins[name] = mod
    end

    # The base plugin for Shrine, implementing all default functionality.
    # Methods are put into a plugin so future plugins can easily override
    # them and call `super` to get the default behavior.
    module Base
      module ClassMethods
        # Generic options for this class, plugins store their options here.
        attr_reader :opts

        # A hash of storages with their symbol identifiers.
        attr_accessor :storages

        # When inheriting Shrine, copy the instance variables into the subclass,
        # and create subclasses of core classes.
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

        # Load a new plugin into the current class. A plugin can be a module
        # which is used directly, or a symbol representing a registered plugin
        # which will be required and then loaded.
        #
        #     Shrine.plugin MyPlugin
        #     Shrine.plugin :my_plugin
        def plugin(plugin, *args, &block)
          plugin = Plugins.load_plugin(plugin) if plugin.is_a?(Symbol)
          plugin.load_dependencies(self, *args, &block) if plugin.respond_to?(:load_dependencies)
          self.include(plugin::InstanceMethods) if defined?(plugin::InstanceMethods)
          self.extend(plugin::ClassMethods) if defined?(plugin::ClassMethods)
          self::UploadedFile.include(plugin::FileMethods) if defined?(plugin::FileMethods)
          self::UploadedFile.extend(plugin::FileClassMethods) if defined?(plugin::FileClassMethods)
          self::Attachment.include(plugin::AttachmentMethods) if defined?(plugin::AttachmentMethods)
          self::Attachment.extend(plugin::AttachmentClassMethods) if defined?(plugin::AttachmentClassMethods)
          self::Attacher.include(plugin::AttacherMethods) if defined?(plugin::AttacherMethods)
          self::Attacher.extend(plugin::AttacherClassMethods) if defined?(plugin::AttacherClassMethods)
          plugin.configure(self, *args, &block) if plugin.respond_to?(:configure)
          plugin
        end

        # Retrieves the storage under the given identifier (can be a Symbol or
        # a String), and raises Shrine::Error if the storage is missing.
        def find_storage(name)
          storages.each { |key, value| return value if key.to_s == name.to_s }
          raise Error, "storage #{name.inspect} isn't registered on #{self}"
        end

        # Generates an instance of Shrine::Attachment to be included in the
        # model class. Example:
        #
        #     class Photo
        #       include Shrine.attachment(:image) # creates a Shrine::Attachment object
        #     end
        def attachment(name, **options)
          self::Attachment.new(name, **options)
        end
        alias [] attachment

        # Instantiates a Shrine::UploadedFile from a hash, and optionally
        # yields the returned object.
        #
        #     data = {"storage" => "cache", "id" => "abc123.jpg", "metadata" => {}}
        #     Shrine.uploaded_file(data) #=> #<Shrine::UploadedFile>
        def uploaded_file(object, &block)
          case object
          when String
            uploaded_file(JSON.parse(object), &block)
          when Hash
            uploaded_file(self::UploadedFile.new(object), &block)
          when self::UploadedFile
            object.tap { |f| yield(f) if block_given? }
          else
            raise Error, "cannot convert #{object.inspect} to a #{self}::UploadedFile"
          end
        end

        # Prints a deprecation warning to standard error.
        def deprecation(message)
          warn "SHRINE DEPRECATION WARNING: #{message}"
        end
      end

      module InstanceMethods
        # The symbol identifier for the storage used by the uploader.
        attr_reader :storage_key

        # The storage object used by the uploader.
        attr_reader :storage

        # Accepts a storage symbol registered in `Shrine.storages`.
        def initialize(storage_key)
          @storage = self.class.find_storage(storage_key)
          @storage_key = storage_key.to_sym
        end

        # The class-level options hash. This should probably not be modified at
        # the instance level.
        def opts
          self.class.opts
        end

        # The main method for uploading files. Takes an IO-like object and an
        # optional context hash (used internally by Shrine::Attacher). It calls
        # user-defined #process, and aferwards it calls #store. The `io` is
        # closed after upload.
        def upload(io, context = {})
          io = processed(io, context) || io
          store(io, context)
        end

        # User is expected to perform processing inside this method, and
        # return the processed files. Returning nil signals that no proccessing
        # has been done and that the original file should be used.
        #
        #     class ImageUploader < Shrine
        #       def process(io, context)
        #         # do processing and return processed files
        #       end
        #     end
        def process(io, context = {})
        end

        # Uploads the file and returns an instance of Shrine::UploadedFile. By
        # default the location of the file is automatically generated by
        # \#generate_location, but you can pass in `:location` to upload to
        # a specific location.
        #
        #     uploader.store(io)
        def store(io, context = {})
          _store(io, context)
        end

        # Returns true if the storage of the given uploaded file matches the
        # storage of this uploader.
        def uploaded?(uploaded_file)
          uploaded_file.storage_key == storage_key.to_s
        end

        # Deletes the given uploaded file and returns it.
        def delete(uploaded_file, context = {})
          _delete(uploaded_file, context)
          uploaded_file
        end

        # Generates a unique location for the uploaded file, preserving the
        # file extension. Can be overriden in uploaders for generating custom
        # location.
        def generate_location(io, context = {})
          extension   = ".#{io.extension}" if io.is_a?(UploadedFile) && io.extension
          extension ||= File.extname(extract_filename(io).to_s).downcase
          basename  = generate_uid(io)

          basename + extension.to_s
        end

        # Extracts filename, size and MIME type from the file, which is later
        # accessible through `UploadedFile#metadata`.
        def extract_metadata(io, context = {})
          {
            "filename"  => extract_filename(io),
            "size"      => extract_size(io),
            "mime_type" => extract_mime_type(io),
          }
        end

        private

        # Attempts to extract the appropriate filename from the IO object.
        def extract_filename(io)
          if io.respond_to?(:original_filename)
            io.original_filename
          elsif io.respond_to?(:path)
            File.basename(io.path)
          end
        end

        # Attempts to extract the MIME type from the IO object.
        def extract_mime_type(io)
          if io.respond_to?(:content_type)
            warn "The \"mime_type\" Shrine metadata field will be set from the \"Content-Type\" request header, which might not hold the actual MIME type of the file. It is recommended to load the determine_mime_type plugin which determines MIME type from file content." unless opts.key?(:mime_type_analyzer)
            io.content_type
          end
        end

        # Extracts the filesize from the IO object.
        def extract_size(io)
          io.size
        end

        # It first asserts that `io` is a valid IO object. It then extracts
        # metadata and generates the location, before calling the storage to
        # upload the IO object, passing the extracted metadata and location.
        # Finally it returns a Shrine::UploadedFile object which represents the
        # file that was uploaded.
        def _store(io, context)
          _enforce_io(io)
          metadata = get_metadata(io, context)
          location = get_location(io, context.merge(metadata: metadata))

          put(io, context.merge(location: location, metadata: metadata))

          self.class.uploaded_file(
            "id"       => location,
            "storage"  => storage_key.to_s,
            "metadata" => metadata,
          )
        end

        # Delegates to #remove.
        def _delete(uploaded_file, context)
          remove(uploaded_file, context)
        end

        # Delegates to #copy.
        def put(io, context)
          copy(io, context)
        end

        # Calls `#upload` on the storage, passing to it the location, metadata
        # and any upload options. The storage might modify the location or
        # metadata that were passed in. The uploaded IO is then closed.
        def copy(io, context)
          location = context[:location]
          metadata = context[:metadata]
          upload_options = context[:upload_options] || {}

          storage.upload(io, location, shrine_metadata: metadata, **upload_options)
        ensure
          io.close rescue nil
        end

        # Delegates to `UploadedFile#delete`.
        def remove(uploaded_file, context)
          uploaded_file.delete
        end

        # Delegates to #process.
        def processed(io, context)
          process(io, context)
        end

        # Retrieves the location for the given IO and context. First it looks
        # for the `:location` option, otherwise it calls #generate_location.
        def get_location(io, context)
          location = context[:location] || generate_location(io, context)
          location or raise Error, "location generated for #{io.inspect} was nil (context = #{context})"
        end

        # If the IO object is a Shrine::UploadedFile, it simply copies over its
        # metadata, otherwise it calls #extract_metadata.
        def get_metadata(io, context)
          if io.is_a?(UploadedFile)
            io.metadata.dup
          else
            extract_metadata(io, context)
          end
        end

        # Asserts that the object is a valid IO object, specifically that it
        # responds to `#read`, `#eof?`, `#rewind`, `#size` and `#close`. If the
        # object doesn't respond to one of these methods, a Shrine::InvalidFile
        # error is raised.
        def _enforce_io(io)
          missing_methods = IO_METHODS.select { |m, a| !io.respond_to?(m) }
          raise InvalidFile.new(io, missing_methods) if missing_methods.any?
        end

        # Generates a unique identifier that can be used for a location.
        def generate_uid(io)
          SecureRandom.hex
        end
      end

      module AttachmentClassMethods
        # Returns the Shrine class that this attachment class is
        # namespaced under.
        attr_accessor :shrine_class

        # Since Attachment is anonymously subclassed when Shrine is subclassed,
        # and then assigned to a constant of the Shrine subclass, make inspect
        # reflect the likely name for the class.
        def inspect
          "#{shrine_class.inspect}::Attachment"
        end
      end

      module AttachmentMethods
        # Instantiates an attachment module for a given attribute name, which
        # can then be included to a model class. Second argument will be passed
        # to an attacher module.
        def initialize(name, **options)
          @name    = name
          @options = options

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}_attacher
              @#{name}_attacher ||= (
                attachments    = self.class.ancestors.grep(Shrine::Attachment)
                attachment     = attachments.find { |mod| mod.attachment_name == :#{name} }
                attacher_class = attachment.shrine_class::Attacher
                options        = attachment.options

                attacher_class.new(self, :#{name}, options)
              )
            end

            def #{name}=(value)
              #{name}_attacher.assign(value)
            end

            def #{name}
              #{name}_attacher.get
            end

            def #{name}_url(*args)
              #{name}_attacher.url(*args)
            end
          RUBY
        end

        # Returns name of the attachment this module provides.
        def attachment_name
          @name
        end

        # Returns options that are to be passed to the Attacher.
        def options
          @options
        end

        # Returns class name with attachment name included.
        #
        #     Shrine[:image].to_s #=> "#<Shrine::Attachment(image)>"
        def to_s
          "#<#{self.class.inspect}(#{attachment_name})>"
        end

        # Returns class name with attachment name included.
        #
        #     Shrine[:image].inspect #=> "#<Shrine::Attachment(image)>"
        def inspect
          "#<#{self.class.inspect}(#{attachment_name})>"
        end

        # Returns the Shrine class that this attachment's class is namespaced
        # under.
        def shrine_class
          self.class.shrine_class
        end
      end

      module AttacherClassMethods
        # Returns the Shrine class that this attacher class is namespaced
        # under.
        attr_accessor :shrine_class

        # Since Attacher is anonymously subclassed when Shrine is subclassed,
        # and then assigned to a constant of the Shrine subclass, make inspect
        # reflect the likely name for the class.
        def inspect
          "#{shrine_class.inspect}::Attacher"
        end

        # Block that is executed in context of Shrine::Attacher during
        # validation. Example:
        #
        #     Shrine::Attacher.validate do
        #       if get.size > 5*1024*1024
        #         errors << "is too big (max is 5 MB)"
        #       end
        #     end
        def validate(&block)
          define_method(:validate_block, &block)
          private :validate_block
        end
      end

      module AttacherMethods
        # Returns the uploader that is used for the temporary storage.
        attr_reader :cache

        # Returns the uploader that is used for the permanent storage.
        attr_reader :store

        # Returns the context that will be sent to the uploader when uploading
        # and deleting. Can be modified with additional data to be sent to the
        # uploader.
        attr_reader :context

        # Returns an array of validation errors created on file assignment in
        # the `Attacher.validate` block.
        attr_reader :errors

        # Returns options passed to Attacher
        attr_reader :options

        # Initializes the necessary attributes.
        def initialize(record, name, **options)
          @options  = options
          @cache   = shrine_class.new(options.fetch(:cache, :cache))
          @store   = shrine_class.new(options.fetch(:store, :store))
          @context = {record: record, name: name}
          @errors  = []
        end

        # Returns the model instance associated with the attacher.
        def record; context[:record]; end

        # Returns the attachment name associated with the attacher.
        def name;   context[:name];   end

        # Receives the attachment value from the form. It can receive an
        # already cached file as a JSON string, otherwise it assumes that it's
        # an IO object and uploads it to the temporary storage. The cached file
        # is then written to the attachment attribute in the JSON format.
        def assign(value)
          if value.is_a?(String)
            return if value == "" || !cache.uploaded?(uploaded_file(value))
            assign_cached(uploaded_file(value))
          else
            uploaded_file = cache!(value, action: :cache) if value
            set(uploaded_file)
          end
        end

        # Accepts a Shrine::UploadedFile object and writes is to the attachment
        # attribute. It then runs file validations, and records that the
        # attachment has changed.
        def set(uploaded_file)
          @old = get unless uploaded_file == get
          _set(uploaded_file)
          validate
        end

        # Runs the validations defined by `Attacher.validate`.
        def validate
          errors.clear
          validate_block if get
        end

        # Returns true if a new file has been attached.
        def changed?
          instance_variable_defined?(:@old)
        end
        alias attached? changed?

        # Plugins can override this if they want something to be done before
        # save.
        def save
        end

        # Deletes the old file and promotes the new one. Typically this should
        # be called after saving the model instance.
        def finalize
          return if !instance_variable_defined?(:@old)
          replace
          remove_instance_variable(:@old)
          _promote(action: :store) if cached?
        end

        # Delegates to #promote, overriden for backgrounding.
        def _promote(uploaded_file = get, **options)
          promote(uploaded_file, **options)
        end

        # Uploads the cached file to store, and writes the stored file to the
        # attachment attribute.
        def promote(uploaded_file = get, **options)
          stored_file = store!(uploaded_file, **options)
          result = swap(stored_file) or _delete(stored_file, action: :abort)
          result
        end

        # Calls #update, overriden in ORM plugins, and returns true if the
        # attachment was successfully updated.
        def swap(uploaded_file)
          update(uploaded_file)
          uploaded_file if uploaded_file == get
        end

        # Deletes the previous attachment that was replaced, typically called
        # after the model instance is saved with the new attachment.
        def replace
          _delete(@old, action: :replace) if @old && !cache.uploaded?(@old)
        end

        # Deletes the current attachment, typically called after destroying the
        # record.
        def destroy
          _delete(get, action: :destroy) if get && !cache.uploaded?(get)
        end

        # Delegates to #delete!, overriden for backgrounding.
        def _delete(uploaded_file, **options)
          delete!(uploaded_file, **options)
        end

        # Returns the URL to the attached file if it's present. It forwards any
        # given URL options to the storage.
        def url(**options)
          get.url(**options) if read
        end

        # Returns true if attachment is present and cached.
        def cached?
          get && cache.uploaded?(get)
        end

        # Returns true if attachment is present and stored.
        def stored?
          get && store.uploaded?(get)
        end

        # Returns a Shrine::UploadedFile instantiated from the data written to
        # the attachment attribute.
        def get
          uploaded_file(read) if read
        end

        # Reads from the `<attachment>_data` attribute on the model instance.
        # It returns nil if the value is blank.
        def read
          value = record.send(data_attribute)
          convert_after_read(value) unless value.nil? || value.empty?
        end

        # Uploads the file using the #cache uploader, passing the #context.
        def cache!(io, **options)
          Shrine.deprecation("Sending :phase to Attacher#cache! is deprecated and will not be supported in Shrine 3. Use :action instead.") if options[:phase]
          cache.upload(io, context.merge(_equalize_phase_and_action(options)))
        end

        # Uploads the file using the #store uploader, passing the #context.
        def store!(io, **options)
          Shrine.deprecation("Sending :phase to Attacher#store! is deprecated and will not be supported in Shrine 3. Use :action instead.") if options[:phase]
          store.upload(io, context.merge(_equalize_phase_and_action(options)))
        end

        # Deletes the file using the uploader, passing the #context.
        def delete!(uploaded_file, **options)
          Shrine.deprecation("Sending :phase to Attacher#delete! is deprecated and will not be supported in Shrine 3. Use :action instead.") if options[:phase]
          store.delete(uploaded_file, context.merge(_equalize_phase_and_action(options)))
        end

        # Enhances `Shrine.uploaded_file` with the ability to recognize uploaded
        # files as JSON strings.
        def uploaded_file(object, &block)
          shrine_class.uploaded_file(object, &block)
        end

        # The name of the attribute on the model instance that is used to store
        # the attachment data. Defaults to `<attachment>_data`.
        def data_attribute
          :"#{name}_data"
        end

        # Returns the Shrine class that this attacher's class is namespaced
        # under.
        def shrine_class
          self.class.shrine_class
        end

        private

        # Assigns a cached file.
        def assign_cached(cached_file)
          set(cached_file)
        end

        # Writes the uploaded file the attachment attribute. Overriden in ORM
        # plugins to additionally save the model instance.
        def update(uploaded_file)
          _set(uploaded_file)
        end

        # Performs validation actually.
        # This method is redefined with `Attacher.validate`.
        def validate_block
        end

        # Converts the UploadedFile to a data hash and writes it to the
        # attribute.
        def _set(uploaded_file)
          data = convert_to_data(uploaded_file) if uploaded_file
          write(data ? convert_before_write(data) : nil)
        end

        # Writes to the `<attachment>_data` attribute on the model instance.
        def write(value)
          record.send(:"#{data_attribute}=", value)
        end

        # Returns the data hash of the given UploadedFile.
        def convert_to_data(uploaded_file)
          uploaded_file.data
        end

        # Returns the hash value dumped to JSON.
        def convert_before_write(value)
          value.to_json
        end

        # Returns the read value unchanged.
        def convert_after_read(value)
          value
        end

        # Temporary method used for transitioning from :phase to :action.
        def _equalize_phase_and_action(options)
          options[:phase]  = options[:action] if options.key?(:action)
          options[:action] = options[:phase] if options.key?(:phase)
          options
        end
      end

      module FileClassMethods
        # Returns the Shrine class that this file class is namespaced under.
        attr_accessor :shrine_class

        # Since UploadedFile is anonymously subclassed when Shrine is subclassed,
        # and then assigned to a constant of the Shrine subclass, make inspect
        # reflect the likely name for the class.
        def inspect
          "#{shrine_class.inspect}::UploadedFile"
        end
      end

      module FileMethods
        # The hash of information which defines this uploaded file.
        attr_reader :data

        # Initializes the uploaded file with the given data hash.
        def initialize(data)
          raise Error, "#{data.inspect} isn't valid uploaded file data" unless data["id"] && data["storage"]

          @data = data
          @data["metadata"] ||= {}
          storage # ensure storage is registered
        end

        # The location where the file was uploaded to the storage.
        def id
          @data.fetch("id")
        end

        # The string identifier of the storage the file is uploaded to.
        def storage_key
          @data.fetch("storage")
        end

        # A hash of file metadata that was extracted during upload.
        def metadata
          @data.fetch("metadata")
        end

        # The filename that was extracted from the uploaded file.
        def original_filename
          metadata["filename"]
        end

        # The extension derived from #id if present, otherwise from
        # #original_filename.
        def extension
          result = File.extname(id)[1..-1] || File.extname(original_filename.to_s)[1..-1]
          result.downcase if result
        end

        # The filesize of the uploaded file.
        def size
          (@io && @io.size) || (metadata["size"] && Integer(metadata["size"]))
        end

        # The MIME type of the uploaded file.
        def mime_type
          metadata["mime_type"]
        end
        alias content_type mime_type

        # Opens an IO object of the uploaded file for reading and yields it to
        # the block, closing it after the block finishes. For opening without
        # a block #to_io can be used.
        #
        #     uploaded_file.open do |io|
        #       puts io.read # prints the content of the file
        #     end
        def open(*args)
          @io = storage.open(id, *args)
          yield @io
        ensure
          @io.close if @io
          @io = nil
        end

        # Calls `#download` on the storage if the storage implements it,
        # otherwise uses #open to stream the underlying IO to a Tempfile.
        def download(*args)
          if storage.respond_to?(:download)
            storage.download(id, *args)
          else
            tempfile = Tempfile.new(["shrine", ".#{extension}"], binmode: true)
            open(*args) { |io| IO.copy_stream(io, tempfile.path) }
            tempfile.tap(&:open)
          end
        end

        # Part of complying to the IO interface. It delegates to the internally
        # opened IO object.
        def read(*args)
          io.read(*args)
        end

        # Part of complying to the IO interface. It delegates to the internally
        # opened IO object.
        def eof?
          io.eof?
        end

        # Part of complying to the IO interface. It delegates to the internally
        # opened IO object.
        def close
          io.close if @io
        end

        # Part of complying to the IO interface. It delegates to the internally
        # opened IO object.
        def rewind
          io.rewind
        end

        # Calls `#url` on the storage, forwarding any given URL options.
        def url(**options)
          storage.url(id, **options)
        end

        # Calls `#exists?` on the storage, which checks whether the file exists
        # on the storage.
        def exists?
          storage.exists?(id)
        end

        # Uploads a new file to this file's location and returns it.
        def replace(io, context = {})
          uploader.upload(io, context.merge(location: id))
        end

        # Calls `#delete` on the storage, which deletes the file from the
        # storage.
        def delete
          storage.delete(id)
        end

        # Returns an opened IO object for the uploaded file.
        def to_io
          io
        end

        # Returns the data hash in the JSON format. Suitable for storing in a
        # database column or passing to a background job.
        def to_json(*args)
          data.to_json(*args)
        end

        # Conform to ActiveSupport's JSON interface.
        def as_json(*args)
          data
        end

        # Returns true if the other UploadedFile is uploaded to the same
        # storage and it has the same #id.
        def ==(other)
          other.is_a?(self.class) &&
          self.id == other.id &&
          self.storage_key == other.storage_key
        end
        alias eql? ==

        # Enables using UploadedFile objects as hash keys.
        def hash
          [id, storage_key].hash
        end

        # Returns an uploader object for the corresponding storage.
        def uploader
          shrine_class.new(storage_key)
        end

        # Returns the storage that this file was uploaded to.
        def storage
          shrine_class.find_storage(storage_key)
        end

        # Returns the Shrine class that this file's class is namespaced under.
        def shrine_class
          self.class.shrine_class
        end

        private

        # Returns an opened IO object for the uploaded file by calling `#open`
        # on the storage.
        def io
          @io ||= storage.open(id)
        end
      end
    end
  end

  extend Plugins::Base::ClassMethods
  plugin Plugins::Base
end
