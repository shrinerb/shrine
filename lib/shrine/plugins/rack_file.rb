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
    #     params[:file] #=>
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
    # uploader and attacher to accept the Rack uploaded file hash as a whole,
    # which is then internally converted into an IO object.
    #
    #     uploader.upload(params[:file])
    #     # or
    #     attacher.assign(params[:file])
    #     # or
    #     user.avatar = params[:file]
    #
    # This especially convenient when doing mass attribute assignment with
    # request parameters. It will also copy the received file information into
    # metadata.
    #
    #     uploaded_file = uploader.upload(params[:file])
    #     uploaded_file.original_filename #=> "cats.png"
    #     uploaded_file.mime_type         #=> "image/png"
    #
    # Note that this plugin is not needed in Rails applications, as Rails
    # already wraps Rack uploaded files in `ActionDispatch::Http::UploadedFile`.
    module RackFile
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
            UploadedFile.new(value)
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

      # This is used to wrap the Rack hash into an IO-like object which Shrine
      # can upload.
      class UploadedFile
        attr_reader :original_filename, :content_type
        attr_accessor :tempfile

        def initialize(tempfile:, filename: nil, type: nil, **)
          @tempfile          = tempfile
          @original_filename = filename
          @content_type      = type
        end

        def path
          @tempfile.path
        end

        def to_io
          @tempfile
        end

        extend Forwardable
        delegate Shrine::IO_METHODS.keys => :@tempfile
      end
    end

    register_plugin(:rack_file, RackFile)
  end
end
