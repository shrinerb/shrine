require "test_helper"

class RecacheTest < Minitest::Test
  def setup
    @attacher = attacher { plugin :recache }
  end

  test "recaching cached files" do
    @attacher.shrine_class.class_eval do
      def process(io, context)
        FakeIO.new(io.read.reverse) if context[:phase] == :recache
      end
    end

    cached_file = @attacher.cache.upload(fakeio("original"))
    @attacher.set(cached_file.to_json)
    @attacher.save

    assert_equal "lanigiro", @attacher.get.read
  end

  test "recaching stored files" do
    @attacher.shrine_class.class_eval do
      def process(io, context)
        FakeIO.new(io.read.reverse) if context[:phase] == :recache
      end
    end

    cached_file = @attacher.store.upload(fakeio("original"))
    @attacher.set(cached_file.to_json)
    @attacher.save

    assert_equal "lanigiro", @attacher.get.read
  end

  test "recaches only if the attachment was assigned" do
    @attacher.shrine_class.class_eval do
      def process(io, context)
        FakeIO.new(io.read.reverse) if context[:phase] == :recache
      end
    end

    cached_file = @attacher.cache.upload(fakeio("original"))
    @attacher.record.avatar_data = cached_file.to_json
    @attacher.save

    assert_equal "original", @attacher.get.read
  end

  test "doesn't recache if attachment is missing" do
    @attacher.save
  end
end
