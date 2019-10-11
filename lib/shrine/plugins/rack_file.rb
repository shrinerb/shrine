# frozen_string_literal: true

require "forwardable"

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/rack_file
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

          Shrine::RackFile.new(hash)
        end
      end

      module AttacherMethods
        # Checks whether a file is a Rack file hash, and in that case wraps the
        # hash in an IO-like object.
        def assign(value, **options)
          if rack_file?(value)
            assign shrine_class.rack_file(value), **options
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

    end

    register_plugin(:rack_file, RackFile)
  end

  # This is used to wrap the Rack hash into an IO-like object which Shrine
  # can upload.
  class RackFile
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
