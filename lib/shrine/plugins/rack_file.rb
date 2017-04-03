require "forwardable"

class Shrine
  module Plugins
    # The `rack_file` plugin enables uploaders to accept Rack uploaded file
    # hashes for uploading.
    #
    #     plugin :rack_file
    #
    # When a file is uploaded to your Rack application using the
    # `multipart/form-data` parameter encoding, Rack converts the uploaded file
    # to a hash.
    #
    #     file_hash #=>
    #     # {
    #     #   name: "file"
    #     #   filename: "cats.png",
    #     #   type: "image/png",
    #     #   tempfile: #<Tempfile:/var/folders/3n/3asd/-Tmp-/RackMultipart201-1476-nfw2-0>,
    #     #   head: "Content-Disposition: form-data; ...",
    #     # }
    #
    # Since Shrine only accepts IO objects, you would normally need to fetch
    # the `:tempfile` object and pass it directly. This plugin enables the
    # attacher to accept the Rack uploaded file hash directly, which is
    # convenient when doing mass attribute assignment.
    #
    #     user.avatar = file_hash
    #     # or
    #     attacher.assign(file_hash)
    #
    # Internally the Rack uploaded file hash will be converted into an IO
    # object using `Shrine.rack_file`, which you can also use directly:
    #
    #     # or YourUploader.rack_file(file_hash)
    #     io = Shrine.rack_file(file_hash)
    #     io.original_filename #=> "cats.png"
    #     io.content_type      #=> "image/png"
    #     io.size              #=> 58342
    #
    # Note that this plugin is not needed in Rails applications, as Rails
    # already wraps the Rack uploaded file hash into an
    # `ActionDispatch::Http::UploadedFile` object.
    module RackFile
      module ClassMethods
        # Accepts a Rack uploaded file hash and wraps it in an IO object.
        def rack_file(hash)
          UploadedFile.new(hash)
        end
      end

      module InstanceMethods
        # If `io` is a Rack uploaded file hash, converts it to an IO-like
        # object and calls `super`.
        def upload(io, context = {})
          super(convert_rack_file(io), context)
        end

        # If `io` is a Rack uploaded file hash, converts it to an IO-like
        # object and calls `super`.
        def store(io, context = {})
          super(convert_rack_file(io), context)
        end

        private

        # If given a Rack uploaded file hash, returns a
        # `Shrine::Plugins::RackFile::UploadedFile` IO-like object wrapping that
        # hash, otherwise returns the value unchanged.
        def convert_rack_file(value)
          if rack_file?(value)
            Shrine.deprecation("Passing a Rack uploaded file hash to Shrine#upload is deprecated, use Shrine.rack_file to convert the Rack file hash into an IO object.")
            self.class.rack_file(value)
          else
            value
          end
        end

        # Returns whether a given value is a Rack uploaded file hash, by
        # checking whether it's a hash with `:tempfile` and `:name` keys.
        def rack_file?(value)
          value.is_a?(Hash) && value.key?(:tempfile) && value.key?(:name)
        end
      end

      module AttacherMethods
        # Checks whether a file is a Rack file hash, and in that case wraps the
        # hash in an IO-like object.
        def assign(value)
          if rack_file?(value)
            assign(shrine_class.rack_file(value))
          else
            super
          end
        end

        private

        # Returns whether a given value is a Rack uploaded file hash, by
        # checking whether it's a hash with `:tempfile` and `:name` keys.
        def rack_file?(value)
          value.is_a?(Hash) && value.key?(:tempfile) && value.key?(:name)
        end
      end

      # This is used to wrap the Rack hash into an IO-like object which Shrine
      # can upload.
      class UploadedFile
        attr_reader :tempfile, :original_filename, :content_type
        alias :to_io :tempfile

        def initialize(hash)
          @tempfile          = hash[:tempfile]
          @original_filename = hash[:filename]
          @content_type      = hash[:type]
        end

        def path
          @tempfile.path
        end

        extend Forwardable
        delegate Shrine::IO_METHODS.keys => :@tempfile
      end
    end

    register_plugin(:rack_file, RackFile)
  end
end
