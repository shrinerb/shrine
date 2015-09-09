require "test_helper"

class StrorageTest < Minitest::Test
  test "`cache` and `store`" do
    uploader = Class.new(Uploadie)
    uploader.cache = "cache"
    assert_equal "cache", uploader.cache

    uploader.store = "store"
    assert_equal "store", uploader.store

    assert_equal Hash[cache: "cache", store: "store"], uploader.storages
  end

  test "every subclass gets its own copy" do
    uploader = Class.new(Uploadie)
    uploader.storages[:foo] = "foo"

    another_uploader = Class.new(uploader)
    assert_equal "foo", another_uploader.storages[:foo]

    another_uploader.storages[:foo] = "bar"
    assert_equal "bar", another_uploader.storages[:foo]
    assert_equal "foo", uploader.storages[:foo]
  end

  test "raising error when storage doesn't exist" do
    assert_raises(Uploadie::Error) do
      Uploadie.new(:foo)
    end

    assert_raises(Uploadie::Error) do
      Uploadie::UploadedFile.new("id" => "123", "storage" => "foo", "metadata" => {})
    end
  end
end
