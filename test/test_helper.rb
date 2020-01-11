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
