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
    block ||= -> { skip "Pending..." }
    define_method(test_name, &block)
  end

  def assert_io(object)
    Uploadie::IO_METHODS.each { |m| assert_respond_to object, m }
  end

  def assert_raises(exception_class, message = nil, &block)
    exception = super(exception_class, &block)
    assert_match message, exception.message if message
    exception
  end

  def uploader(plugin, &block)
    uploader_class = Class.new(Uploadie)
    uploader_class.cache = Uploadie::Storage::Memory.new
    uploader_class.store = @storage = Uploadie::Storage::Memory.new
    uploader_class.plugin(plugin) unless plugin == :bare
    uploader_class.class_eval(&block) if block
    uploader_class.new(:store)
  end

  def fakeio(content = "file", **options)
    fakeio = FakeIO.new(content, **options)
    fakeio.singleton_class.class_eval do
      attr_reader :original_filename if options[:filename]
      attr_reader :content_type if options[:content_type]
    end
    fakeio
  end

  def image
    File.open("test/fixtures/image.jpg")
  end
end

class FakeIO
  def initialize(content, filename: nil, content_type: nil)
    @io = StringIO.new(content)
    @original_filename = filename
    @content_type = content_type
  end

  extend Forwardable
  delegate Uploadie::IO_METHODS => :@io
end
