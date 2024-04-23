Warning[:deprecated] = true if RUBY_VERSION >= "2.7"

require "bundler/setup"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    add_filter "/lib/shrine/storage/linter.rb"
  end
end

ENV["MT_NO_EXPECTATIONS"] = "1" # disable Minitest's expectations monkey-patches

require "minitest/autorun"
require "minitest/pride"

# Mocha still references the old constant
MiniTest = Minitest unless defined?(MiniTest)
require "mocha/minitest"

require "shrine"

Shrine.logger = Logger.new(nil) # disable mime_type warnings

Mocha.configure { |config| config.stubbing_non_existent_method = :prevent }

require "./test/support/shrine_helper"
require "./test/support/file_helper"
require "./test/support/logging_helper"
require "./test/support/ext"

class RubySerializer
  def self.dump(data)
    data.to_s
  end

  def self.load(data)
    eval(data)
  end
end

ACCEPT_RANGES_HEADER = Rack.release >= "3" ? "accept-ranges" : "Accept-Ranges"
CACHE_CONTROL_HEADER = Rack.release >= "3" ? "cache-control" : "Cache-Control"
CONTENT_DISPOSITION_HEADER = Rack.release >= "3" ? "content-disposition" : "Content-Disposition"
CONTENT_LENGTH_HEADER = Rack.release >= "3" ? "content-length" : "Content-Length"
CONTENT_RANGE_HEADER = Rack.release >= "3" ? "content-range" : "Content-Range"
CONTENT_TYPE_HEADER = Rack.release >= "3" ? "content-type" : "Content-Type"
ETAG_HEADER = Rack.release >= "3" ? "etag" : "ETag"
LOCATION_HEADER = Rack.release >= "3" ? "location" : "Location"
