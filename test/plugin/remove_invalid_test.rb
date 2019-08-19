require "test_helper"
require "shrine/plugins/remove_invalid"

describe Shrine::Plugins::RemoveInvalid do
  before do
    @attacher = attacher { plugin :remove_invalid }
    @shrine   = @attacher.shrine_class
  end

  describe "Attacher" do
    describe "#change" do
      it "deletes and removes invalid cached files" do
        @attacher.class.validate { errors << "error" }

        cached_file = @shrine.upload(fakeio, :cache)
        @attacher.change(cached_file)

        refute cached_file.exists?
        assert_nil @attacher.file
      end

      it "deletes and removes invalid stored files" do
        @attacher.class.validate { errors << "error" }

        stored_file = @shrine.upload(fakeio, :store)
        @attacher.change(stored_file)

        refute stored_file.exists?
        assert_nil @attacher.file
      end

      it "reverts the previous attached file" do
        previous_file = @attacher.upload(fakeio)
        @attacher.file = previous_file

        @attacher.class.validate { errors << "error" }
        @attacher.attach(fakeio)

        assert_equal previous_file, @attacher.file
      end

      it "removes dirty state from attacher" do
        @attacher.class.validate { errors << "error" }

        @attacher.attach(fakeio)

        refute @attacher.changed?
      end

      it "doesn't remove when validations have passed" do
        @attacher.attach(fakeio)

        refute_nil @attacher.file
        assert @attacher.file.exists?
        assert @attacher.changed?
      end

      it "works with versions" do
        @shrine.plugin :versions

        file = @shrine.upload(fakeio, :cache)
        @attacher.class.validate { errors << "error" }
        @attacher.change(thumb: file)

        assert_nil @attacher.file
        refute file.exists?
      end

      it "integrates with backgrounding" do
        @shrine.plugin :backgrounding

        file = @shrine.upload(fakeio, :cache)

        @attacher.destroy_block do |attacher|
          assert_equal file, attacher.file
          @block_called = true
        end

        @attacher.class.validate { errors << "error" }
        @attacher.change(file)

        assert_nil @attacher.file
        assert @block_called
      end
    end
  end
end
