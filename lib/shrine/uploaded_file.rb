# frozen_string_literal: true

require "json"
require "tempfile"
require "uri"

class Shrine
  # Core class that represents a file uploaded to a storage.
  # Base implementation is defined in InstanceMethods and ClassMethods.
  class UploadedFile
    @shrine_class = ::Shrine

    module ClassMethods
      # Returns the Shrine class that this file class is namespaced under.
      attr_accessor :shrine_class

      # Since UploadedFile is anonymously subclassed when Shrine is subclassed,
      # and then assigned to a constant of the Shrine subclass, make inspect
      # reflect the likely name for the class.
      def inspect
        "#{shrine_class.inspect}::UploadedFile"
      end
    end

    module InstanceMethods
      # The location where the file was uploaded to the storage.
      attr_reader :id

      # The identifier of the storage the file is uploaded to.
      attr_reader :storage_key

      # A hash of file metadata that was extracted during upload.
      attr_reader :metadata

      # Initializes the uploaded file with the given data hash.
      def initialize(data)
        @id          = data[:id]              || data["id"]
        @storage_key = data[:storage]&.to_sym || data["storage"]&.to_sym
        @metadata    = data[:metadata]        || data["metadata"]        || {}

        fail Error, "#{data.inspect} isn't valid uploaded file data" unless @id && @storage_key

        storage # ensure storage is registered
      end

      # The filename that was extracted from the uploaded file.
      def original_filename
        metadata["filename"]
      end

      # The extension derived from #id if present, otherwise it's derived
      # from #original_filename.
      def extension
        result = File.extname(id)[1..-1] || File.extname(original_filename.to_s)[1..-1]
        result.sub!(/\?.+$/, "") if result && id =~ URI::regexp # strip query params for shrine-url
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

      # Shorthand for accessing metadata values.
      def [](key)
        metadata[key]
      end

      # Calls `#open` on the storage to open the uploaded file for reading.
      # Most storages will return a lazy IO object which dynamically
      # retrieves file content from the storage as the object is being read.
      #
      # If a block is given, the opened IO object is yielded to the block,
      # and at the end of the block it's automatically closed. In this case
      # the return value of the method is the block return value.
      #
      # If no block is given, the opened IO object is returned.
      #
      #     uploaded_file.open #=> IO object returned by the storage
      #     uploaded_file.read #=> "..."
      #     uploaded_file.close
      #
      #     # or
      #
      #     uploaded_file.open { |io| io.read } # the IO is automatically closed
      def open(**options)
        @io.close if @io
        @io = _open(**options)

        return @io unless block_given?

        begin
          yield @io
        ensure
          close
          @io = nil
        end
      end

      # Streams content into a newly created Tempfile and returns it.
      #
      # If a block is given, the opened Tempfile object is yielded to the
      # block, and at the end of the block it's automatically closed and
      # deleted. In this case the return value of the method is the block
      # return value.
      #
      # If no block is given, the opened Tempfile is returned.
      #
      #     uploaded_file.download
      #     #=> #<File:/var/folders/.../20180302-33119-1h1vjbq.jpg>
      #
      #     # or
      #
      #     uploaded_file.download { |tempfile| tempfile.read } # tempfile is deleted
      def download(**options)
        tempfile = Tempfile.new(["shrine", ".#{extension}"], binmode: true)
        stream(tempfile, **options)
        tempfile.open

        block_given? ? yield(tempfile) : tempfile
      ensure
        tempfile.close! if ($! || block_given?) && tempfile
      end

      # Streams uploaded file content into the specified destination. The
      # destination object is given directly to `IO.copy_stream`, so it can
      # be either a path on disk or an object that responds to `#write`.
      #
      # If the uploaded file is already opened, it will be simply rewinded
      # after streaming finishes. Otherwise the uploaded file is opened and
      # then closed after streaming.
      #
      #     uploaded_file.stream(StringIO.new)
      #     # or
      #     uploaded_file.stream("/path/to/destination")
      def stream(destination, **options)
        if opened?
          IO.copy_stream(io, destination)
          io.rewind
        else
          open(**options) { |io| IO.copy_stream(io, destination) }
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
      def rewind
        io.rewind
      end

      # Part of complying to the IO interface. It delegates to the internally
      # opened IO object.
      def close
        io.close if opened?
      end

      # Returns whether the file has already been opened.
      def opened?
        !!@io
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
      def replace(io, **options)
        uploader.upload(io, **options, location: id)
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

      # Returns serializable hash representation of the uploaded file.
      def data
        { "id" => id, "storage" => storage_key.to_s, "metadata" => metadata }
      end

      # Returns true if the other UploadedFile is uploaded to the same
      # storage and it has the same #id.
      def ==(other)
        self.class       == other.class       &&
        self.id          == other.id          &&
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

      # Returns simplified inspect output.
      def inspect
        "#<#{self.class.inspect} storage=#{storage_key.inspect} id=#{id.inspect} metadata=#{metadata.inspect}>"
      end

      private

      # Returns an opened IO object for the uploaded file by calling `#open`
      # on the storage.
      def io
        @io ||= _open
      end

      def _open(**options)
        storage.open(id, **options)
      end
    end

    extend ClassMethods
    include InstanceMethods
  end
end
