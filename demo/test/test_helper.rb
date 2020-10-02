require "bundler/setup"

ENV["MT_NO_EXPECTATIONS"] = "1" # disable Minitest's expectations monkey-patches

require "minitest/autorun"
require "minitest/pride"

require "capybara"
require "capybara/dsl"
require "capybara/minitest"
require "capybara/cuprite"

require "./app"
require "sucker_punch/testing/inline"

Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800])
end

Capybara.default_driver = :cuprite
Capybara.app = ShrineDemo
Capybara.ignore_hidden_elements = false

class Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def teardown
    Capybara.reset_sessions!
    DB[:photos].truncate
    DB[:albums].truncate
  end

  def fixture(filename)
    File.expand_path("test/fixtures/#{filename}")
  end
end
