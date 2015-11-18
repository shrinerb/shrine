require "bundler/setup"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end
end

require "minitest/autorun"
require "minitest/pride"
require "minitest/hooks/default"
require "mocha/mini_test"

require "shrine"

require "./test/support/helpers"

Minitest::Spec.include TestHelpers::Generic
