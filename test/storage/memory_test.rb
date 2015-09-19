require "test_helper"
require "uploadie/storage/memory"
require "uploadie/storage"

class MemoryTest < Minitest::Test
  def memory(*args)
    Uploadie::Storage::Memory.new(*args)
  end

  def setup
    @memory = memory
  end

  test "passes the lint" do
    Uploadie::Storage::Lint.call(@memory)
  end
end
