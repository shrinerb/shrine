class Uploadie
  def self.version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 4
    MINOR = 3
    TINY  = 1
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
