require "test_helper"
require "shrine/storage/s3"
require "shrine/storage/linter"

describe Shrine::Storage::Memory do
  before do
    @memory = Shrine::Storage::Memory.new
  end

  it "passes the linter" do
    Shrine::Storage::Linter.call(@memory)
  end
end
