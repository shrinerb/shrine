require "test_helper"
require "shrine/plugins/attacher_options"

describe Shrine::Plugins::AttacherOptions do
  before do
    @attacher = attacher { plugin :attacher_options }
    @shrine   = @attacher.shrine_class
  end

  describe "Attacher" do
    describe "#attach_options" do
      it "merges options" do
        assert_equal Hash.new, @attacher.attach_options
        @attacher.attach_options(foo: "bar")
        assert_equal Hash[foo: "bar"], @attacher.attach_options
        @attacher.attach_options(baz: "quux")
        assert_equal Hash[foo: "bar", baz: "quux"], @attacher.attach_options
      end
    end

    describe "#promote_options" do
      it "merges options" do
        assert_equal Hash.new, @attacher.promote_options
        @attacher.promote_options(foo: "bar")
        assert_equal Hash[foo: "bar"], @attacher.promote_options
        @attacher.promote_options(baz: "quux")
        assert_equal Hash[foo: "bar", baz: "quux"], @attacher.promote_options
      end
    end

    describe "#destroy_options" do
      it "merges options" do
        assert_equal Hash.new, @attacher.destroy_options
        @attacher.destroy_options(foo: "bar")
        assert_equal Hash[foo: "bar"], @attacher.destroy_options
        @attacher.destroy_options(baz: "quux")
        assert_equal Hash[foo: "bar", baz: "quux"], @attacher.destroy_options
      end
    end

    describe "#attach_cached" do
      it "forwards attach options" do
        io = fakeio
        @attacher.attach_options(foo: "bar")
        @shrine.expects(:upload).with(io, :cache, { foo: "bar", action: :cache })
        @attacher.attach_cached(io)
      end

      it "still works without any attach options" do
        @attacher.attach_cached(fakeio)
      end
    end

    describe "#attach" do
      it "forwards attach options" do
        io = fakeio
        @attacher.attach_options(foo: "bar")
        @shrine.expects(:upload).with(io, :store, { foo: "bar" })
        @attacher.attach(io)
      end

      it "still works without any attach options" do
        @attacher.attach(fakeio)
      end
    end

    describe "#promote_cached" do
      it "forwards promote options" do
        @attacher.attach_cached(fakeio)
        @attacher.promote_options(foo: "bar")
        @shrine.expects(:upload).with(@attacher.file, :store, { foo: "bar", action: :store })
        @attacher.promote_cached
      end

      it "works with backgrounding plugin" do
        @shrine.plugin :backgrounding
        @attacher.promote_block do |attacher, **options|
          assert_equal Hash[foo: "bar", action: :store], options
        end
        @attacher.promote_options(foo: "bar")
        @attacher.attach_cached(fakeio)
        @attacher.promote_cached
      end

      it "still works without any promote options" do
        @attacher.attach_cached(fakeio)
        @attacher.promote_cached
      end
    end

    describe "#destroy_previous" do
      it "forwards destroy options for backgrounding plugin" do
        @shrine.plugin :backgrounding
        @attacher.destroy_block do |attacher, **options|
          assert_equal Hash[foo: "bar"], options
        end
        @attacher.destroy_options(foo: "bar")
        @attacher.file = @attacher.upload(fakeio)
        @attacher.attach(fakeio)
        @attacher.destroy_previous
      end

      it "still works without destroy options" do
        @attacher.file = @attacher.upload(fakeio)
        @attacher.attach(fakeio)
        @attacher.destroy_previous
      end
    end

    describe "#destroy_attached" do
      it "forwards destroy options for backgrounding plugin" do
        @shrine.plugin :backgrounding
        @attacher.destroy_block do |attacher, **options|
          assert_equal Hash[foo: "bar"], options
        end
        @attacher.destroy_options(foo: "bar")
        @attacher.attach(fakeio)
        @attacher.destroy_attached
      end

      it "still works without destroy options" do
        @attacher.attach(fakeio)
        @attacher.destroy_attached
      end
    end
  end
end
