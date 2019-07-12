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
require "mocha/minitest"

require "shrine"

Shrine.logger = Logger.new(nil) # disable mime_type warnings

Mocha::Configuration.prevent(:stubbing_non_existent_method)

require "./test/support/generic_helper"
require "./test/support/deprecated_helper"
require "./test/support/logging_helper"
