# frozen_string_literal: true

require "forwardable"

class Shrine
  # IO-like object from string.
  class DataFile
    extend Forwardable

    attr_reader :content_type, :original_filename

    delegate %i[read size rewind eof?] => :@io

    def initialize(content, content_type: nil, filename: nil)
      @content_type      = content_type
      @original_filename = filename
      @io                = StringIO.new(content)
    end

    def to_io
      @io
    end

    def close
      @io.close
      @io.string.clear # deallocate string
    end
  end
end
