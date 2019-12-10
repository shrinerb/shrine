require "test_helper"
require "shrine/plugins/remove_invalid"

describe Shrine::Plugins::RemoveInvalid do
  before do
    @attacher = attacher { plugin :remove_invalid }
    @shrine   = @attacher.shrine_class
  end

  describe "Attacher" do
    describe "#validate" do
      it "deletes and removes invalid cached files" do
        @attacher.class.validate { errors << "error" }
        file = @attacher.attach_cached(fakeio)

        refute file.exists?
        assert_nil @attacher.file
      end

      it "deletes and removes invalid stored files" do
        @attacher.class.validate { errors << "error" }
        file = @attacher.attach(fakeio)

        refute file.exists?
        assert_nil @attacher.file
      end

      it "assigns back the previous file" do
        previous_file = @attacher.attach(fakeio)
        @attacher.class.validate { errors << "error" }
        @attacher.attach(fakeio)

        assert_equal previous_file, @attacher.file
      end

      it "removes dirty state from attacher" do
        @attacher.class.validate { errors << "error" }
        @attacher.attach(fakeio)

        refute @attacher.changed?
      end

      it "doesn't deassign when validations have passed" do
        file = @attacher.attach(fakeio)

        assert_equal file, @attacher.file
        assert @attacher.file.exists?
        assert @attacher.changed?
      end

      describe "with derivatives plugin" do
        before do
          @shrine.plugin :derivatives
          @attacher = @shrine::Attacher.new
        end

        it "assigns back derivatives" do
          file        = @attacher.set @attacher.upload(fakeio)
          derivatives = @attacher.add_derivatives(one: fakeio)

          @attacher.class.validate { errors << "error" }
          @attacher.assign(fakeio)

          assert_equal file,        @attacher.file
          assert_equal derivatives, @attacher.derivatives

          assert derivatives[:one].exists?
        end

        it "destroys derivatives" do
          file        = @attacher.set @attacher.upload(fakeio)
          derivatives = @attacher.add_derivatives(one: fakeio)

          @attacher.class.validate { errors << "error" }
          @attacher.validate

          refute file.exists?
          refute derivatives[:one].exists?
        end

        it "deassigns dirty" do
          file        = @attacher.attach(fakeio)
          derivatives = @attacher.add_derivatives(one: fakeio)

          @attacher.class.validate { errors << "error" }
          @attacher.validate

          assert_nil   @attacher.file
          assert_empty @attacher.derivatives
        end

        it "deassign clean" do
          file        = @attacher.set(@attacher.upload(fakeio))
          derivatives = @attacher.add_derivatives(one: fakeio)

          @attacher.class.validate { errors << "error" }
          @attacher.validate

          assert_nil   @attacher.file
          assert_empty @attacher.derivatives
        end
      end

      describe "with versions plugin" do
        before do
          @shrine.plugin :versions
        end

        it "destroys versions" do
          @attacher.class.validate { errors << "error" }
          files = @attacher.attach(thumb: fakeio)

          assert_nil @attacher.file
          refute files[:thumb].exists?
        end
      end
    end
  end
end
