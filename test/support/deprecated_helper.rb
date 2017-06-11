require "minitest/hooks/default"

class Minitest::HooksSpec
  def self.deprecated(name, &block)
    it("#{name} (deprecated)") do
      deprecated{instance_exec(&block)}
    end
  end

  def deprecated
    $stderr = StringIO.new
    yield
    $stderr = STDERR
  end
end
