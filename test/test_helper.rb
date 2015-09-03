require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"
require "minitest/hooks/test"

require "uploadie"
require "uploadie/storage/memory"

require "stringio"
require "forwardable"

class Minitest::Test
  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
    block ||= -> { skip "" }
    define_method(test_name, &block)
  end

  def assert_io(object)
    Uploadie::IO_METHODS.each { |m| assert_respond_to object, m }
  end

  def assert_raises(exception_class, message = nil, &block)
    exception = super(exception_class, &block)
    assert_match message, exception.message
  end

  def uploader(plugin, &block)
    uploader_class = Class.new(Uploadie)
    uploader_class.storages[:memory] = @storage = Uploadie::Storage::Memory.new
    uploader_class.plugin plugin unless plugin == :bare
    uploader_class.instance_exec(&block) if block
    uploader_class.new(:memory)
  end
end

class FakeIO
  def initialize(content, filename: nil, content_type: nil)
    @io = StringIO.new(content)
    @original_filename = filename and extend OriginalFilename
    @content_type = content_type and extend ContentType
  end

  extend Forwardable
  delegate Uploadie::IO_METHODS => :@io

  module OriginalFilename
    attr_reader :original_filename
  end

  module ContentType
    attr_reader :content_type
  end
end
