require "stringio"

class Minitest::Test
  def assert_logged(pattern)
    result = nil
    logged = capture_logged { result = yield }

    assert_match pattern, logged

    result
  end

  def refute_logged(pattern)
    result = nil
    logged = capture_logged { result = yield }

    refute_match pattern, logged

    result
  end

  def capture_logged
    previous_logger = Shrine.logger
    output = StringIO.new
    Shrine.logger = Logger.new(output)
    Shrine.logger.formatter = -> (*, message) { "#{message}\n" }

    yield

    output.string
  ensure
    Shrine.logger = previous_logger
  end
end
