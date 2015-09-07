require "test_helper"

class MultipleFilesTest < Minitest::Test
  def setup
    @uploader = uploader(:multiple_files)
  end

  test "returning an array of uploaded files" do
    uploaded_files = @uploader.upload([fakeio, fakeio])

    uploaded_files.each do |uploaded_file|
      assert_kind_of Uploadie::UploadedFile, uploaded_file
    end
  end

  test "generating array of locations" do
    uploaded_files = @uploader.upload([fakeio, fakeio])
    id1, id2 = uploaded_files.map(&:id)

    refute_equal id1, id2
  end

  test "using a given array of locations" do
    uploaded_files = @uploader.upload([fakeio, fakeio], ["foo", "bar"])
    id1, id2 = uploaded_files.map(&:id)

    assert_equal "foo", id1
    assert_equal "bar", id2
  end

  test "validating the array of files" do
    assert_raises(Uploadie::Error) { @uploader.upload(["foo", fakeio]) }
    assert_raises(Uploadie::Error) { @uploader.upload([fakeio, "foo"]) }
  end

  test "putting the array of files on proper locations" do
    uploaded_files = @uploader.upload([fakeio("file1"), fakeio("file2")])
    id1, id2 = uploaded_files.map(&:id)

    assert_equal "file1", @storage.read(id1)
    assert_equal "file2", @storage.read(id2)
  end

  test "storing the array of files" do
    uploaded_files = @uploader.store([fakeio, fakeio], ["foo", "bar"])
    id1, id2 = uploaded_files.map(&:id)

    assert_equal "foo", id1
    assert_equal "bar", id2
  end

  test "regular upload" do
    uploaded_file = @uploader.upload(fakeio("image"), "location")

    assert_equal "location", uploaded_file.id
    assert_equal "image", @storage.read("location")
  end
end
