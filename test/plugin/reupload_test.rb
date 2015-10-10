require "test_helper"

describe "the reupload plugin" do
  def setup
    @attacher = attacher { plugin :reupload }
  end

  it "reuploads cached files" do
    @attacher.shrine_class.class_eval do
      def process(io, context)
        FakeIO.new(io.read.reverse) if context[:phase] == :reupload
      end
    end

    @attacher.assign(fakeio("original"))
    @attacher.save

    assert_equal "lanigiro", @attacher.get.read
  end

  it "reuploads stored files" do
    @attacher.shrine_class.class_eval do
      def process(io, context)
        FakeIO.new(io.read.reverse) if context[:phase] == :reupload
      end
    end

    @attacher.assign(fakeio("original"))
    @attacher.save

    assert_equal "lanigiro", @attacher.get.read
  end

  it "reuploads only if the attachment was assigned" do
    @attacher.shrine_class.class_eval do
      def process(io, context)
        FakeIO.new(io.read.reverse) if context[:phase] == :reupload
      end
    end

    cached_file = @attacher.cache.upload(fakeio("original"))
    @attacher.record.avatar_data = cached_file.to_json
    @attacher.save

    assert_equal "original", @attacher.get.read
  end

  it "doesn't reupload if attachment is missing" do
    @attacher.save
  end
end
