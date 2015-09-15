require "forwardable"

class Uploadie
  module Plugins
    module RackFile
      module InstanceMethods
        def upload(io, context = {})
          if io.is_a?(Hash) && io.key?(:tempfile)
            super(UploadedFile.new(io), context)
          else
            super
          end
        end
      end

      class UploadedFile
        attr_reader :original_filename, :content_type

        def initialize(tempfile:, filename: nil, type: nil, head: nil)
          @tempfile          = tempfile
          @original_filename = filename
          @content_type      = type
        end

        def to_io
          @tempfile
        end

        extend Forwardable
        delegate Uploadie::IO_METHODS => :@tempfile
      end
    end

    register_plugin(:rack_file, RackFile)
  end
end
