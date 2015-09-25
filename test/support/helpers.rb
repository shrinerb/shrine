require "./test/support/fakeio"
require "./test/support/memory"

module TestHelpers
  module Generic
    def uploader(storage_key = :store, &block)
      uploader_class = Class.new(Shrine)
      uploader_class.cache = Shrine::Storage::Memory.new
      uploader_class.store = Shrine::Storage::Memory.new
      uploader_class.class_eval(&block) if block
      uploader_class.new(storage_key)
    end

    def attacher(*args, &block)
      uploader = uploader(*args, &block)
      user = Struct.new(:avatar_data).new
      user.class.include uploader.class[:avatar]
      user.avatar_attacher
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
      File.open(image_path)
    end

    def image_path
      "test/fixtures/image.jpg"
    end

    def image_url
      "https://cdn0.iconfinder.com/data/icons/octicons/1024/mark-github-128.png?foo=bar"
    end

    def invalid_url
      "https://google.com/foo"
    end

    def data_uri(content_type = "image/png")
      "data:#{content_type};base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
    end
  end

  module Interactions
    include Minitest::Hooks

    def self.included(test)
      super
      require "vcr"
      VCR.configure do |config|
        config.cassette_library_dir = "test/fixtures"
        config.hook_into :webmock
      end
    end

    def around
      VCR.use_cassette("interactions") { super }
    end
  end

  module Rack
    def self.included(test)
      super
      require "rack/test"
      test.include ::Rack::Test::Methods
    end

    def response
      last_response
    end

    def body
      require "json"
      JSON.parse(response.body)
    rescue JSON::ParserError
    end
  end
end
