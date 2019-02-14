# frozen_string_literal: true

require "forwardable"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/rack_file.md] on GitHub.
    #
    # [doc/plugins/rack_file.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/rack_file.md
    module RackFile
      module ClassMethods
        # Accepts a Rack uploaded file hash and wraps it in an IO object.
        def rack_file(hash)
          if hash[:filename]
            # Rack can sometimes return the filename binary encoded, so we force
            # the encoding to utf-8
            hash = hash.merge(
              filename: hash[:filename].dup.force_encoding(Encoding::UTF_8)
            )
          end

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
        delegate [:read, :size, :rewind, :eof?, :close] => :@tempfile
      end
    end

    register_plugin(:rack_file, RackFile)
  end
end
