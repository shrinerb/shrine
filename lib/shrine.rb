# frozen_string_literal: true

require "shrine/version"
require "shrine/uploaded_file"
require "shrine/attacher"
require "shrine/attachment"
require "shrine/plugins"

require "securerandom"
require "json"
require "tempfile"
require "logger"

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

  @opts = {}
  @storages = {}
  @logger = Logger.new(STDOUT)
  @logger.formatter = -> (*, message) { "#{message}\n" }

  module ClassMethods
    # Generic options for this class, plugins store their options here.
    attr_reader :opts

    # A hash of storages with their symbol identifiers.
    attr_accessor :storages

    # A logger instance.
    attr_accessor :logger

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
    # a String), raising Shrine::Error if the storage is missing.
    def find_storage(name)
      storages[name.to_sym] || storages[name.to_s] or fail Error, "storage #{name.inspect} isn't registered on #{self}"
    end

    # Generates an instance of Shrine::Attachment to be included in the
    # model class. Example:
    #
    #     class Photo
    #       include Shrine::Attachment(:image) # creates a Shrine::Attachment object
    #     end
    def Attachment(name, *args)
      self::Attachment.new(name, *args)
    end
    alias attachment Attachment
    alias [] Attachment

    # Uploads the file to the specified storage. It delegates to `Shrine#upload`.
    #
    #     Shrine.upload(io, :store) #=> #<Shrine::UploadedFile>
    def upload(io, storage, **options)
      new(storage).upload(io, **options)
    end

    # Instantiates a Shrine::UploadedFile from a hash, and optionally
    # yields the returned object.
    #
    #     data = {"storage" => "cache", "id" => "abc123.jpg", "metadata" => {}}
    #     Shrine.uploaded_file(data) #=> #<Shrine::UploadedFile>
    def uploaded_file(object)
      case object
      when String
        uploaded_file(JSON.parse(object))
      when Hash
        object = JSON.parse(object.to_json) if object.keys.grep(Symbol).any? # deep stringify keys
        self::UploadedFile.new(object)
      when self::UploadedFile
        object
      else
        fail Error, "cannot convert #{object.inspect} to a #{self}::UploadedFile"
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

    # Prints a warning to the logger.
    def warn(message)
      Shrine.logger.warn "SHRINE WARNING: #{message}"
    end

    # Prints a deprecation warning to the logger.
    def deprecation(message)
      Shrine.logger.warn "SHRINE DEPRECATION WARNING: #{message}"
    end
  end

  module InstanceMethods
    # The symbol identifier for the storage used by the uploader.
    attr_reader :storage_key

    # The storage object used by the uploader.
    attr_reader :storage

    # Accepts a storage symbol registered in `Shrine.storages`.
    #
    #     Shrine.new(:store)
    def initialize(storage_key)
      @storage     = self.class.find_storage(storage_key)
      @storage_key = storage_key.to_sym
    end

    # The main method for uploading files. Takes an IO-like object and an
    # optional context hash (used internally by Shrine::Attacher). It calls
    # user-defined #process, and afterwards it calls #store. The `io` is
    # closed after upload.
    #
    #   uploader.upload(io)
    #   uploader.upload(io, metadata: { "foo" => "bar" })           # add metadata
    #   uploader.upload(io, location: "path/to/file")               # specify location
    #   uploader.upload(io, upload_options: { acl: "public-read" }) # add upload options
    def upload(io, **options)
      _enforce_io(io)

      metadata = get_metadata(io, **options)
      location = get_location(io, **options, metadata: metadata)

      _upload(io, **options, location: location, metadata: metadata)

      self.class::UploadedFile.new(
        "id"       => location,
        "storage"  => storage_key.to_s,
        "metadata" => metadata,
      )
    end

    # Generates a unique location for the uploaded file, preserving the
    # file extension. Can be overriden in uploaders for generating custom
    # location.
    def generate_location(io, metadata: {}, **options)
      basic_location(io, metadata: metadata)
    end

    # Extracts filename, size and MIME type from the file, which is later
    # accessible through UploadedFile#metadata.
    def extract_metadata(io, **options)
      {
        "filename"  => extract_filename(io),
        "size"      => extract_size(io),
        "mime_type" => extract_mime_type(io),
      }
    end

    # The class-level options hash. This should probably not be modified at
    # the instance level.
    def opts
      self.class.opts
    end

    private

    def _upload(io, location:, metadata:, upload_options: {}, **)
      storage.upload(io, location, shrine_metadata: metadata, **upload_options)
    ensure
      io.close rescue nil
    end

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
        Shrine.warn "The \"mime_type\" Shrine metadata field will be set from the \"Content-Type\" request header, which might not hold the actual MIME type of the file. It is recommended to load the determine_mime_type plugin which determines MIME type from file content."
        io.content_type.split(";").first # exclude media type parameters
      end
    end

    # Extracts the filesize from the IO object.
    def extract_size(io)
      io.size if io.respond_to?(:size)
    end

    # Generates a basic location for an uploaded file
    def basic_location(io, metadata:)
      extension   = ".#{io.extension}" if io.is_a?(UploadedFile) && io.extension
      extension ||= File.extname(extract_filename(io).to_s).downcase
      basename    = generate_uid(io)

      basename + extension
    end

    # If the IO object is a Shrine::UploadedFile, it simply copies over its
    # metadata, otherwise it calls #extract_metadata.
    def get_metadata(io, metadata: nil, **options)
      if io.is_a?(UploadedFile) && metadata != true
        result = io.metadata.dup
      elsif metadata != false
        result = extract_metadata(io, **options)
      else
        result = {}
      end

      result = result.merge(metadata) if metadata.is_a?(Hash)
      result
    end

    # Retrieves the location for the given IO and context. First it looks
    # for the `:location` option, otherwise it calls #generate_location.
    def get_location(io, location: nil, **options)
      location ||= generate_location(io, options)
      location or fail Error, "location generated for #{io.inspect} was nil"
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

  extend ClassMethods
  include InstanceMethods
end
