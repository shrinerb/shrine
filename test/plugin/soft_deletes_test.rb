require "test_helper"

class SoftDeletesTest < Minitest::Test
  def setup
    @uploader = uploader(:soft_deletes)
    @user = Struct.new(:avatar_data).new
    @attacher = @uploader.class::Attacher.new(@user, :avatar)
  end

  test "doesn't delete file on nullifying" do
    @attacher.set(fakeio)
    @attacher.save

    uploaded_file = @attacher.get
    @attacher.set(nil)
    @attacher.save

    assert uploaded_file.exists?
  end

  test "doesn't delete file on replacing" do
    @attacher.set(fakeio)
    @attacher.save

    uploaded_file = @attacher.get
    @attacher.set(fakeio)
    @attacher.save

    assert uploaded_file.exists?
  end
end
