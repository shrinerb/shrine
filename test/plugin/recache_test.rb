require "test_helper"

describe "the recache plugin" do
  def setup
    @attacher = attacher { plugin :recache }
  end

  it "recaches cached files" do
    @attacher.shrine_class.class_eval do
      def process(io, context)
        FakeIO.new(io.read.reverse) if context[:phase] == :recache
      end
    end

    @attacher.assign(fakeio("original"))
    @attacher.save

    assert_equal "lanigiro", @attacher.get.read
  end

  it "recaches only if the attachment was assigned" do
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

  it "doesn't recache if attachment is missing" do
    @attacher.save
  end
end
