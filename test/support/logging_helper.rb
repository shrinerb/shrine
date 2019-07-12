require "stringio"

class Minitest::HooksSpec
  def assert_logged(pattern)
    previous_logger = Shrine.logger
    output = StringIO.new
    Shrine.logger = Logger.new(output)

    yield

    assert_match pattern, output.string
  ensure
    Shrine.logger = previous_logger
  end
end
