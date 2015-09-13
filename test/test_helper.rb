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

  def image_url
    "https://cdn0.iconfinder.com/data/icons/octicons/1024/mark-github-128.png?foo=bar"
  end

  def invalid_url
    "https://a.com"
  end
end

module TestHelpers
  module Interactions
    include Minitest::Hooks

    def self.included(test)
      super
      require "vcr"
      VCR.configure do |config|
        config.cassette_library_dir = "test/fixtures"
        config.default_cassette_options = {record: :new_episodes}
        config.hook_into :webmock
      end
    end

    def around
      VCR.use_cassette("interactions") { super }
    end
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
