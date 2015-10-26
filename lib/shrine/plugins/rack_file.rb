require "forwardable"

class Shrine
  module Plugins
    # The rack_file plugin enables models to accept Rack file hashes as
    # attachments.
    #
    #     rack_file #=>
    #     # {
    #     #   filename: "cats.png",
    #     #   type: "image/png",
    #     #   tempfile: #<Tempfile:/var/folders/3n/3asd/-Tmp-/RackMultipart201-1476-nfw2-0>,
    #     #   head: "Content-Disposition: form-data; ...",
    #     # }
    #     user.avatar = rack_file
    #     user.avatar.original_filename #=> "cats.png"
    #     user.avatar.mime_type         #=> "image/png"
    #
    # Internally the plugin wraps the Rack file hash into an IO-like object,
    # and this is what is passed to `Shrine#upload`.
    #
    #     plugin :rack_file
    module RackFile
      module AttacherMethods
        # Checks whether a file is a Rack file hash, and in that case wraps the
        # hash in an IO-like object.
        def assign(value)
          if value.is_a?(Hash) && value.key?(:tempfile)
            super(UploadedFile.new(value))
          else
            super
          end
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
