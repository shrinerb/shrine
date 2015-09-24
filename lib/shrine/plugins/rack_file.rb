require "forwardable"

class Shrine
  module Plugins
    module RackFile
      module AttacherMethods
        def set(value)
          if value.is_a?(Hash) && value.key?(:tempfile)
            super(UploadedFile.new(value))
          else
            super
          end
        end
      end

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
