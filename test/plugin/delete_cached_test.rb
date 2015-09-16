require "test_helper"

class DeleteCachedTest < Minitest::Test
  def setup
    @attacher = attacher { plugin :delete_cached }
  end

  test "deletes cached files" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.save

    refute uploaded_file.exists?
  end

  test "handles setting already stored files" do
    stored_file = @attacher.store.upload(fakeio)
    @attacher.set(stored_file)
    @attacher.save

    assert stored_file.exists?
  end

  test "handles no files" do
    @attacher.save
  end
end
