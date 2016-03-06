require "./test/support/fakeio"
require "./test/support/memory"
require "base64"

module TestHelpers
  module Generic
    def uploader(storage_key = :store, &block)
      uploader_class = Class.new(Shrine)
      uploader_class.storages[:cache] = Shrine::Storage::Memory.new
      uploader_class.storages[:store] = Shrine::Storage::Memory.new
      uploader_class.class_eval(&block) if block
      uploader_class.new(storage_key)
    end

    def attacher(*args, &block)
      uploader = uploader(*args, &block)
      Object.send(:remove_const, "User") if defined?(User) # for warnings
      user_class = Object.const_set("User", Struct.new(:avatar_data, :id))
      user_class.include uploader.class[:avatar]
      user_class.new.avatar_attacher
    end

    def teardown
      super
      Object.send(:remove_const, "User") if defined?(User)
    end

    def fakeio(content = "file", **options)
      FakeIO.new(content, **options)
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

    def data_uri_raw(content_type = "image/png")
      "data:#{content_type},#{Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAUA")}"
    end

    def io?(object)
      missing_methods = Shrine::IO_METHODS.reject do |m, a|
        object.respond_to?(m) && [a.count, -1].include?(object.method(m).arity)
      end
      missing_methods.empty?
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
        config.allow_http_connections_when_no_cassette = true
      end
    end

    def around
      VCR.use_cassette(cassette) { super }
    end
  end
end
