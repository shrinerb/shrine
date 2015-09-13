require "test_helper"

class SoftDeleteTest < Minitest::Test
  def setup
    @uploader = uploader(:soft_delete)
    @user = Struct.new(:avatar_data).new
    @attacher = @uploader.class::Attacher.new(@user, :avatar)
  end

  test "doesn't delete file on #destroy" do
    @attacher.set(fakeio)
    @attacher.save
    uploaded_file = @attacher.get

    @attacher.destroy

    assert uploaded_file.exists?
  end
end
