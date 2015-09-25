require "forwardable"
require "stringio"

class FakeIO
  def initialize(content, filename: nil, content_type: nil)
    @io = StringIO.new(content)
    @original_filename = filename
    @content_type = content_type
  end

  extend Forwardable
  delegate Shrine::IO_METHODS.keys => :@io
end
