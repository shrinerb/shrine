# frozen_string_literal: true

require "securerandom"
require "json"
require "tempfile"

require "shrine/version"

require "shrine/attacher"
require "shrine/attachment"
require "shrine/plugins"
require "shrine/uploaded_file"

# Core class that represents uploader.
# Base implementation is defined in InstanceMethods and ClassMethods.
class Shrine
  # A generic exception used by Shrine.
  class Error < StandardError; end

  # Raised when a file is not a valid IO.
  class InvalidFile < Error
    def initialize(io, missing_methods)
      super "#{io.inspect} is not a valid IO object (it doesn't respond to \
        #{missing_methods.map{|m, _|"##{m}"}.join(", ")})"
    end
  end

  # Methods which an object has to respond to in order to be considered
  # an IO object, along with their arguments.
  IO_METHODS = {
    read:   [:length, :outbuf],
    eof?:   [],
    rewind: [],
    size:   [],
    close:  [],
  }
  deprecate_constant(:IO_METHODS) if RUBY_VERSION > "2.3"

  @opts = {}
  @storages = {}

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
    def attachment(name, *args)
      self::Attachment.new(name, *args)
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

    # Temporarily converts an IO-like object into a file. If the input IO
    # object is already a file, it simply yields it to the block, otherwise
    # it copies IO content into a Tempfile object which is then yielded and
    # afterwards deleted.
    #
    #     Shrine.with_file(io) { |file| file.path }
    def with_file(io)
      if io.respond_to?(:path)
        yield io
      elsif io.is_a?(UploadedFile)
        io.download { |tempfile| yield tempfile }
      else
        Tempfile.create("shrine-file", binmode: true) do |file|
          IO.copy_stream(io, file.path)
          io.rewind

          yield file
        end
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
    # user-defined #process, and afterwards it calls #store. The `io` is
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
      basename    = generate_uid(io)

      basename + extension
    end

    # Extracts filename, size and MIME type from the file, which is later
    # accessible through UploadedFile#metadata.
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
      if io.respond_to?(:content_type) && io.content_type
        warn "The \"mime_type\" Shrine metadata field will be set from the \"Content-Type\" request header, which might not hold the actual MIME type of the file. It is recommended to load the determine_mime_type plugin which determines MIME type from file content."
        io.content_type.split(";").first # exclude media type parameters
      end
    end

    # Extracts the filesize from the IO object.
    def extract_size(io)
      io.size if io.respond_to?(:size)
    end

    # It first asserts that `io` is a valid IO object. It then extracts
    # metadata and generates the location, before calling the storage to
    # upload the IO object, passing the extracted metadata and location.
    # Finally it returns a Shrine::UploadedFile object which represents the
    # file that was uploaded.
    def _store(io, context)
      _enforce_io(io)

      metadata = get_metadata(io, context)
      metadata = metadata.merge(context[:metadata]) if context[:metadata]

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
      location       = context[:location]
      metadata       = context[:metadata]
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
      missing_methods = %i[read eof? rewind close].select { |m| !io.respond_to?(m) }
      raise InvalidFile.new(io, missing_methods) if missing_methods.any?
    end

    # Generates a unique identifier that can be used for a location.
    def generate_uid(io)
      SecureRandom.hex
    end
  end
end

[Shrine, Shrine::UploadedFile, Shrine::Attacher, Shrine::Attachment].each do |core_class|
  core_class.include core_class.const_get(:InstanceMethods)
  core_class.extend core_class.const_get(:ClassMethods)
end
