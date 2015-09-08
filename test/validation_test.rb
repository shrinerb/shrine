require "test_helper"

class ValidationTest < Minitest::Test
  def setup
    @uploader = uploader(:bare)
    @user = Struct.new(:image_data).new
    @attacher = @uploader.class::Attacher.new(@user, :image)
  end

  test "IO is invalid if validation errors are nonempty" do
    assert @uploader.valid?(fakeio, {})

    def @uploader.validate(io, context); [:foo]; end

    refute @uploader.valid?(fakeio, {})
  end

  test "raising validation error" do
    def @uploader.validate(io, context); [:foo]; end

    exception = assert_raises(Uploadie::ValidationFailed) { @uploader.upload(fakeio) }
    assert_equal [:foo], exception.errors
  end

  test "attacher is valid by default" do
    assert_empty @attacher.errors
    assert @attacher.valid?

    @attacher.set(fakeio)
    assert @attacher.valid?
  end

  test "attacher validates the IO" do
    @attacher.set(fakeio)
    store = @attacher.store
    def store.validate(io, context); [:foo]; end

    refute @attacher.valid?
    refute_empty @attacher.errors

    def store.validate(io, context); []; end

    assert @attacher.valid?
    assert_empty @attacher.errors
  end
end
