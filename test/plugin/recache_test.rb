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

  it "doesn't recache if attachment is missing" do
    @attacher.save
  end

  it "recaches only cached files" do
    @attacher.assign(fakeio)
    @attacher._promote

    @attacher.save

    assert_equal "store", @attacher.get.storage_key
  end
end
