require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"
require "minitest/hooks/test"

require "shrine"

require "./test/support/helpers"

class Minitest::Test
  include TestHelpers::Generic

  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
    block ||= -> { skip "Pending..." }
    define_method(test_name, &block)
  end
end
