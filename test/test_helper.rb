require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"
require "minitest/hooks/default"

require "shrine"

require "./test/support/helpers"

Minitest::Spec.include TestHelpers::Generic
