require "test_helper"

describe "the background_helpers plugin" do
  before do
    @attacher = attacher { plugin :background_helpers }
  end

  it "enables background promoting" do
    @attacher.class.promote do |cached_file|
      @fiber = Fiber.new { promote(cached_file) }
    end
    @attacher.assign(fakeio)
    @attacher._promote

    assert_equal "cache", @attacher.get.storage_key
    @attacher.instance_variable_get("@fiber").resume
    assert_equal "store", @attacher.get.storage_key
  end

  it "doesn't call promoting block when there is nothing to promote" do
    @attacher.assign(fakeio)
    @attacher._promote
    @attacher.class.promote do
      @fiber = Fiber.new { promote(get) }
    end
    @attacher._promote

    refute @attacher.instance_variable_defined?("@fiber")
  end

  it "enables background replacing" do
    @attacher.class.delete do |uploaded_file, phase:|
      @fiber = Fiber.new {
        shrine_class.delete(uploaded_file, context.merge(phase: phase))
      }
    end
    uploaded_file = @attacher.assign(fakeio)
    @attacher.assign(fakeio)
    @attacher.replace

    assert uploaded_file.exists?
    @attacher.instance_variable_get("@fiber").resume
    refute uploaded_file.exists?
  end

  it "enables background destroying" do
    @attacher.class.delete do |uploaded_file, phase:|
      @fiber = Fiber.new {
        shrine_class.delete(uploaded_file, context.merge(phase: phase))
      }
    end
    uploaded_file = @attacher.assign(fakeio)
    @attacher.destroy
    @attacher.replace

    assert uploaded_file.exists?
    @attacher.instance_variable_get("@fiber").resume
    refute uploaded_file.exists?
  end
end
