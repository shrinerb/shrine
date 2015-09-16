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

  test "can keep replaced files also" do
    @attacher = attacher { plugin :soft_delete, replaced: true }

    uploaded_file = @attacher.set(fakeio)
    @attacher.set(fakeio)
    @attacher.save

    assert uploaded_file.exists?

    uploaded_file = @attacher.set(fakeio)
    @attacher.set(nil)
    @attacher.save

    assert uploaded_file.exists?
  end
end
