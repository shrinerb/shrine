require "test_helper"

class MultipleFilesTest < Minitest::Test
  def setup
    @uploader = uploader(:multiple_files) do
      def _generate_location(io, context)
        (context[:type] || super).to_s
      end
    end
  end

  test "uploading and storing" do
    [:upload, :store].each do |action|
      uploaded_files = @uploader.send(action, [fakeio, fakeio])

      assert_kind_of Uploadie::UploadedFile, uploaded_files[0]
      assert_kind_of Uploadie::UploadedFile, uploaded_files[1]

      refute_equal uploaded_files[0].id, uploaded_files[1].id

      uploaded_files = @uploader.send(action, [fakeio, fakeio], [{type: :foo}, {type: :bar}])

      assert_equal "foo", uploaded_files[0].id
      assert_equal "bar", uploaded_files[1].id
    end
  end

  test "validating the array of files" do
    assert_raises(Uploadie::Error) { @uploader.upload(["foo", fakeio]) }
    assert_raises(Uploadie::Error) { @uploader.store([fakeio, "foo"]) }
  end

  test "regular upload" do
    uploaded_file = @uploader.upload(fakeio("image"), {type: :avatar})

    assert_equal "avatar", uploaded_file.id
    assert_equal "image", @storage.read(uploaded_file.id)
  end
end
