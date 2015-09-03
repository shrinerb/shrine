require "test_helper"

class OptsTest < Minitest::Test
  test "every subclass gets its own copy" do
    uploader = Class.new(Uploadie)
    uploader.opts[:foo] = "foo"

    another_uploader = Class.new(uploader)
    assert_equal "foo", another_uploader.opts[:foo]

    another_uploader.opts[:foo] = "bar"
    assert_equal "bar", another_uploader.opts[:foo]
    assert_equal "foo", uploader.opts[:foo]
  end

  test "inheritance duplicates collection values" do
    uploader = Class.new(Uploadie)
    uploader.opts[:a] = ["a"]
    uploader.opts[:b] = {"b" => "b"}
    uploader.opts[:c] = ["c"].freeze

    another_uploader = Class.new(uploader)

    another_uploader.opts[:a] << "a"
    assert_equal ["a", "a"], another_uploader.opts[:a]
    assert_equal ["a"],      uploader.opts[:a]

    another_uploader.opts[:b].update("b" => nil)
    assert_equal({"b" => nil}, another_uploader.opts[:b])
    assert_equal({"b" => "b"}, uploader.opts[:b])

    assert_equal ["c"], another_uploader.opts[:c]
  end
end
