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
require "minitest/hooks/default"
require "mocha/mini_test"

require "shrine"

class Shrine
  def warn(*); end # disable mime_type warnings
  #def self.deprecation(*); end
end

require "./test/support/generic_helper"
require "./test/support/deprecated_helper"
