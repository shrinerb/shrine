require "test_helper"

describe "background_delete plugin" do
  def attacher(&block)
    super() { plugin :background_delete, &block }
  end

  it "enables background deleting when replacing" do
    @attacher = attacher do |uploaded_file, context|
      @fiber = Fiber.new { uploaded_file.delete }
    end
    uploaded_file = @attacher.set(fakeio)
    @attacher.set(fakeio)
    @attacher.replace

    assert uploaded_file.exists?
    @fiber.resume
    refute uploaded_file.exists?
  end

  it "enables background deleting when destroying" do
    @attacher = attacher do |uploaded_file, context|
      @fiber = Fiber.new { uploaded_file.delete }
    end
    uploaded_file = @attacher.set(fakeio)
    @attacher.destroy
    @attacher.replace

    assert uploaded_file.exists?
    @fiber.resume
    refute uploaded_file.exists?
  end
end
