require "test_helper"

class ClassTest < Minitest::Test
  def setup
    @shrine = uploader.class
  end

  test "#uploaded_file accepts JSON" do
    uploaded_file = @shrine.new(:cache).upload(fakeio)
    retrieved = @shrine.uploaded_file(uploaded_file.to_json)

    assert_equal uploaded_file, retrieved
  end

  test "#uploaded_file accepts a hash" do
    uploaded_file = @shrine.new(:cache).upload(fakeio)
    retrieved = @shrine.uploaded_file(uploaded_file.data)

    assert_equal uploaded_file, retrieved
  end

  test "#uploaded_file accepts an UploadedFile" do
    uploaded_file = @shrine.new(:cache).upload(fakeio)
    retrieved = @shrine.uploaded_file(uploaded_file)

    assert_equal uploaded_file, retrieved
  end

  test "#uploaded_file raises an error on invalid input" do
    assert_raises(Shrine::Error) { @shrine.uploaded_file(:foo) }
  end

  test "#delete deletes the uploaded file" do
    uploaded_file = @shrine.new(:cache).upload(fakeio)
    @shrine.delete uploaded_file

    refute uploaded_file.exists?
  end

  test "#io! raises an error if given object is not an IO" do
    @shrine.io!(fakeio)
    assert_raises(Shrine::InvalidFile) { @shrine.io!(:foo) }
  end

  test "io? returns whether the given object is an IO" do
    assert @shrine.io?(fakeio)
    refute @shrine.io?(:foo)
  end
end
