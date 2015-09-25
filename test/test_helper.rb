require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"

require "shrine"

require "./test/support/fakeio"
require "./test/support/test_helpers"

class Minitest::Test
  include TestHelpers::Generic

  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
    block ||= -> { skip "Pending..." }
    define_method(test_name, &block)
  end
end
