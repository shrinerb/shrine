require "test_helper"

require "shrine/storage/memory"
require "shrine/storage"

class MemoryTest < Minitest::Test
  def memory(*args)
    Shrine::Storage::Memory.new(*args)
  end

  def setup
    @memory = memory
  end

  test "passes the lint" do
    Shrine::Storage::Lint.call(@memory)
  end
end
