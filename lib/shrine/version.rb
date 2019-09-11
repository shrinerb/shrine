# frozen_string_literal: true

class Shrine
  def self.version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 3
    MINOR = 0
    TINY  = 0
    PRE   = "beta2"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
