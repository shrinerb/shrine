require "test_helper"

class DeleteCachedTest < Minitest::Test
  def setup
    @uploader = uploader(:delete_cached)
    @user = Struct.new(:avatar_data).new
    @attacher = @uploader.class::Attacher.new(@user, :avatar)
  end

  test "deletes cached files" do
    uploaded_file = @attacher.set(fakeio)
    @attacher.commit!

    refute uploaded_file.exists?
  end

  test "handles setting already stored files" do
    stored_file = @attacher.store.upload(fakeio)
    @attacher.set(stored_file)
    @attacher.commit!

    assert stored_file.exists?
  end

  test "handles no files" do
    @attacher.commit!
  end
end
