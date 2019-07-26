require "test_helper"
require "shrine/plugins/processing"

describe Shrine::Plugins::Processing do
  before do
    @uploader = uploader { plugin :processing }
    @shrine   = @uploader.class
  end

  describe "Shrine" do
    describe "#upload" do
      it "executes defined processing" do
        @shrine.process(:foo) { |io, **| FakeIO.new(io.read.reverse) }
        file = @uploader.upload(fakeio("file"), action: :foo)
        assert_equal "elif", file.read
      end

      it "executes in context of uploader, and passes right variables" do
        minitest = self

        @shrine.process(:foo) do |io, **options|
          minitest.assert_kind_of Shrine, self
          minitest.assert_respond_to io, :read
          minitest.assert_equal :foo, options[:action]

          FakeIO.new(io.read.reverse)
        end

        @uploader.upload(fakeio, action: :foo)
      end

      it "executes all defined blocks where output of previous is input to next" do
        @shrine.process(:foo) { |io, **| FakeIO.new("changed") }
        @shrine.process(:foo) { |io, **| FakeIO.new(io.read.reverse) }

        file = @uploader.upload(fakeio, action: :foo)

        assert_equal "degnahc", file.read
      end

      it "allows blocks to return nil" do
        @shrine.process(:foo) { |io, **| nil }
        @shrine.process(:foo) { |io, **| FakeIO.new(io.read.reverse) }

        file = @uploader.upload(fakeio("file"), action: :foo)

        assert_equal "elif", file.read
      end

      it "executes defined blocks only if actions match" do
        @shrine.process(:foo) { |io, **| FakeIO.new(io.read.reverse) }

        file = @uploader.upload(fakeio("file"))

        assert_equal "file", file.read
      end

      it "doesn't overwrite existing definitions when loading the plugin" do
        @shrine.process(:foo) { |io, **| FakeIO.new("processed") }
        @shrine.plugin :processing

        file = @uploader.upload(fakeio, action: :foo)

        assert_equal "processed", file.read
      end

      it "copies processing definitions on subclassing" do
        @shrine.process(:foo) { |io, **| FakeIO.new("#{io.read} once") }

        subclass = Class.new(@shrine)
        subclass.process(:foo) { |io, **| FakeIO.new("#{io.read} twice") }

        uploaded_by_parent = @uploader.upload(fakeio("file"), action: :foo)
        uploaded_by_subclass = subclass.upload(fakeio("file"), :store, action: :foo)

        refute_equal @shrine.opts[:processing], subclass.opts[:processing]
        assert_equal 1, @shrine.opts[:processing][:foo].size
        assert_equal 2, subclass.opts[:processing][:foo].size

        assert_equal "file once",       uploaded_by_parent.read
        assert_equal "file once twice", uploaded_by_subclass.read
      end
    end
  end
end
