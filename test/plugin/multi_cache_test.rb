require "test_helper"
require "shrine/plugins/multi_cache"

describe Shrine::Plugins::MultiCache do
  before do
    @attacher = attacher { plugin :multi_cache, additional_cache: [:other_cache] }
    @shrine   = @attacher.shrine_class
  end

  describe "Attacher" do
    describe "#attach_cached" do
      it "allows attaching files uploaded to additional cache" do
        file = @attacher.upload(fakeio, :other_cache)

        @attacher.attach_cached(file.data)

        assert_equal :other_cache, @attacher.file.storage_key
        assert @attacher.cached?
      end

      it "can still attach files uploaded to primary cache" do
        file = @attacher.upload(fakeio, :cache)

        @attacher.attach_cached(file.data)

        assert_equal :cache, @attacher.file.storage_key
        assert @attacher.cached?
      end

      it "still uploads files to primary cache" do
        @attacher.attach_cached(fakeio)

        assert_equal :cache, @attacher.file.storage_key
        assert @attacher.cached?
      end
    end

    describe "#promote_cached" do
      it "promotes files uploaded to additional cache" do
        file = @attacher.upload(fakeio, :other_cache)

        @attacher.attach_cached(file.data)
        @attacher.promote_cached

        assert_equal :store, @attacher.file.storage_key
        assert @attacher.stored?
      end

      it "promotes files uploaded to primary cache" do
        file = @attacher.upload(fakeio, :cache)

        @attacher.attach_cached(file.data)
        @attacher.promote_cached

        assert_equal :store, @attacher.file.storage_key
        assert @attacher.stored?
      end
    end
  end
end
