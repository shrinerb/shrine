class Shrine
  def self.version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 2
    MINOR = 5
    TINY  = 0
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
