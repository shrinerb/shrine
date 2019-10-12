require "test_helper"
require "shrine/plugins/backgrounding"

describe Shrine::Plugins::Backgrounding do
  before do
    @attacher = attacher { plugin :backgrounding }
    @shrine   = @attacher.shrine_class

    @job = nil
  end

  describe "Attacher" do
    describe ".promote_block" do
      it "registers a promote block" do
        assert_nil @attacher.class.promote_block

        @attacher.class.promote_block {}

        assert_instance_of Proc, @attacher.class.promote_block
      end

      it "survives inheritance" do
        @attacher.class.promote_block {}

        shrine_subclass   = Class.new(@shrine)
        attacher_subclass = shrine_subclass::Attacher

        assert_equal @attacher.class.promote_block, attacher_subclass.promote_block
      end
    end

    describe ".destroy_block" do
      it "registers a destroy block" do
        assert_nil @attacher.class.destroy_block

        @attacher.class.destroy_block {}

        assert_instance_of Proc, @attacher.class.destroy_block
      end

      it "survives inheritance" do
        @attacher.class.destroy_block {}

        shrine_subclass   = Class.new(@shrine)
        attacher_subclass = shrine_subclass::Attacher

        assert_equal @attacher.class.destroy_block, attacher_subclass.destroy_block
      end
    end

    describe "#promote_block" do
      it "registers a promote block" do
        assert_nil @attacher.promote_block

        @attacher.promote_block {}

        assert_instance_of Proc, @attacher.promote_block
      end

      it "overrides a class-level promote block" do
        @attacher.class.promote_block {}

        @attacher = @attacher.class.new

        assert_equal @attacher.class.promote_block, @attacher.promote_block

        @attacher.promote_block {}

        refute_equal @attacher.class.promote_block, @attacher.promote_block
      end
    end

    describe "#destroy_block" do
      it "registers a destroy block" do
        assert_nil @attacher.class.destroy_block

        @attacher.class.destroy_block {}

        assert_instance_of Proc, @attacher.class.destroy_block
      end

      it "overrides a class-level destroy block" do
        @attacher.class.destroy_block {}

        @attacher = @attacher.class.new

        assert_equal @attacher.class.destroy_block, @attacher.destroy_block

        @attacher.destroy_block { |attacher| }

        refute_equal @attacher.class.destroy_block, @attacher.destroy_block
      end
    end

    describe "#promote_cached" do
      it "calls class-level promote block" do
        @attacher.class.promote_block do |attacher|
          @job = Fiber.new { attacher.promote }
        end

        @attacher = @attacher.class.new
        @attacher.attach_cached(fakeio)
        @attacher.promote_cached

        assert @attacher.cached?

        @job.resume

        assert @attacher.stored?
      end

      it "calls instance-level promote block" do
        @attacher.promote_block do |attacher|
          @job = Fiber.new { attacher.promote }
        end

        @attacher.attach_cached(fakeio)
        @attacher.promote_cached

        assert @attacher.cached?

        @job.resume

        assert @attacher.stored?
      end

      it "calls default promotion when no promote blocks are registered" do
        @attacher.attach_cached(fakeio)
        @attacher.promote_cached

        assert @attacher.stored?
      end

      it "doesn't call the block when there is nothing to promote" do
        @attacher.promote_block do |attacher|
          @job = Fiber.new { attacher.promote }
        end

        @attacher.attach(fakeio)
        @attacher.promote_cached

        assert @attacher.stored?
        assert_nil @job
      end
    end

    describe "#promote_background" do
      it "evaluates promote block without attacher argument inside Attacher instance" do
        this = nil
        @attacher.promote_block do |**options|
          this = self
          promote
        end

        @attacher.attach_cached(fakeio)
        @attacher.promote_background

        assert_equal @attacher, this
        assert @attacher.stored?
      end

      it "calls promote block with attacher argument" do
        this = nil
        @attacher.promote_block do |attacher, **options|
          this = self
          attacher.promote
        end

        @attacher.attach_cached(fakeio)
        @attacher.promote_background

        assert_equal self, this
        assert @attacher.stored?
      end

      it "accepts additional options" do
        @attacher.promote_block { |**options| promote(**options) }

        @attacher.attach_cached(fakeio)
        @attacher.promote_background(location: "foo")

        assert_equal "foo", @attacher.file.id
      end

      it "raises exception when promote block is not registered" do
        @attacher.attach_cached(fakeio)

        assert_raises Shrine::Error do
          @attacher.promote_background
        end
      end
    end

    describe "#destroy_previous" do
      it "calls class-level destroy block" do
        @attacher.class.destroy_block do |attacher|
          @job = Fiber.new { attacher.destroy }
        end

        @attacher = @attacher.class.new
        previous_file = @attacher.attach(fakeio)
        @attacher.attach(nil)
        @attacher.destroy_previous

        assert previous_file.exists?

        @job.resume

        refute previous_file.exists?
      end

      it "calls instance-level destroy block" do
        @attacher.destroy_block do |attacher|
          @job = Fiber.new { attacher.destroy }
        end

        previous_file = @attacher.attach(fakeio)
        @attacher.attach(nil)
        @attacher.destroy_previous

        assert previous_file.exists?

        @job.resume

        refute previous_file.exists?
      end

      it "calls default destroy when no destroy blocks are registered" do
        previous_file = @attacher.attach(fakeio)
        @attacher.attach(nil)
        @attacher.destroy_previous

        refute previous_file.exists?
      end

      it "doesn't call the block when there is nothing to destroy" do
        @attacher.destroy_block do |attacher|
          @job = Fiber.new { attacher.destroy }
        end

        previous_file = @attacher.attach_cached(fakeio)
        @attacher.assign(fakeio)

        assert previous_file.exists?
        assert_nil @job
      end
    end

    describe "#destroy_cached" do
      it "calls class-level destroy block" do
        @attacher.class.destroy_block do |attacher|
          @job = Fiber.new { attacher.destroy }
        end

        @attacher = @attacher.class.new
        @attacher.attach(fakeio)
        @attacher.destroy_attached

        assert @attacher.file.exists?

        @job.resume

        refute @attacher.file.exists?
      end

      it "calls instance-level destroy block" do
        @attacher.destroy_block do |attacher|
          @job = Fiber.new { attacher.destroy }
        end

        @attacher.attach(fakeio)
        @attacher.destroy_attached

        assert @attacher.file.exists?

        @job.resume

        refute @attacher.file.exists?
      end

      it "calls default destroy when no destroy blocks are registered" do
        @attacher.attach(fakeio)
        @attacher.destroy_attached

        refute @attacher.file.exists?
      end

      it "doesn't call the block when there is nothing to destroy" do
        @attacher.destroy_block do |attacher|
          @job = Fiber.new { attacher.destroy }
        end

        @attacher.attach_cached(fakeio)
        @attacher.destroy_attached

        assert @attacher.file.exists?
        assert_nil @job
      end
    end

    describe "#destroy_background" do
      it "evaluates destroy block without attacher argument inside Attacher instance" do
        this = nil
        @attacher.destroy_block do
          this = self
          destroy
        end

        @attacher.attach(fakeio)
        @attacher.destroy_background

        assert_equal @attacher, this
        refute @attacher.file.exists?
      end

      it "calls destroy block with attacher argument" do
        this = nil
        @attacher.destroy_block do |attacher|
          this = self
          attacher.destroy
        end

        @attacher.attach(fakeio)
        @attacher.destroy_background

        assert_equal self, this
        refute @attacher.file.exists?
      end

      it "raises exception when destroy block is not registered" do
        @attacher.attach(fakeio)

        assert_raises do
          @attacher.destroy_background
        end
      end
    end
  end
end
