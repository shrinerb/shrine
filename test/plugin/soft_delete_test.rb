require "test_helper"

class SoftDeleteTest < Minitest::Test
  def setup
    @attacher = attacher { plugin :soft_delete }
  end

  test "doesn't delete file on #destroy" do
    @attacher.set(fakeio)
    @attacher.save
    uploaded_file = @attacher.get

    @attacher.destroy

    assert uploaded_file.exists?
  end
end
