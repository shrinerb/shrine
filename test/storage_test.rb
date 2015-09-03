require "test_helper"

class StrorageTest < Minitest::Test
  test "every subclass gets its own copy" do
    uploader = Class.new(Uploadie)
    uploader.storages[:foo] = "foo"

    another_uploader = Class.new(uploader)
    assert_equal "foo", another_uploader.storages[:foo]

    another_uploader.storages[:foo] = "bar"
    assert_equal "bar", another_uploader.storages[:foo]
    assert_equal "foo", uploader.storages[:foo]
  end
end
