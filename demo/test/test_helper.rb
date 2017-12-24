require "bundler/setup"

ENV["MT_NO_EXPECTATIONS"] = "1" # disable Minitest's expectations monkey-patches

require "minitest/autorun"
require "minitest/pride"

require "selenium/webdriver"
require "capybara"
require "capybara/dsl"
require "capybara/minitest"

require "./app"
require "sucker_punch/testing/inline"

Capybara.register_driver :headless_chrome do |app|
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    chromeOptions: { args: %w(headless disable-gpu) }
  )

  Capybara::Selenium::Driver.new app,
    browser: :chrome,
    desired_capabilities: capabilities
end

Capybara.default_driver = :headless_chrome
Capybara.app = ShrineDemo
Capybara.ignore_hidden_elements = false

class Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def teardown
    Capybara.reset_sessions!
    DB.from(:photos).truncate
    DB.from(:albums).truncate
  end

  def fixture(filename)
    File.expand_path("test/fixtures/#{filename}")
  end
end
