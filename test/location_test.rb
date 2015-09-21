require "test_helper"
require "ostruct"

class LocationTest < Minitest::Test
  def setup
    @uploader = uploader(:store)
  end

  test "generated location is unique" do
    uploaded_file = @uploader.upload(fakeio("image"))
    assert_equal "image", @uploader.storage.read(uploaded_file.id)

    another_uploaded_file = @uploader.upload(fakeio)
    refute_equal uploaded_file.id, another_uploaded_file.id
  end

  test "generated location preserves the extension" do
    # Rails file
    uploaded_file = @uploader.upload(fakeio(filename: "avatar.jpg"))
    assert_match /\.jpg$/, uploaded_file.id

    # Uploaded file
    second_uploaded_file = @uploader.upload(uploaded_file)
    assert_match /\.jpg$/, second_uploaded_file.id

    # File
    uploaded_file = @uploader.upload(File.open(__FILE__))
    assert_match /\.rb$/, uploaded_file.id
  end

  test "generated location handles no filename" do
    uploaded_file = @uploader.upload(fakeio)

    assert_match /^[\w-]+$/, uploaded_file.id
  end

  test "generated location uses context to build the directory" do
    uploaded_file = @uploader.upload(fakeio, record: OpenStruct.new(id: 123), name: :avatar)

    assert_match %r{^openstruct/123/avatar/[\w-]+$}, uploaded_file.id
  end

  test "uploading uses :location if available, even if #generate_location was overriden" do
    @uploader.singleton_class.class_eval do
      def generate_location(io, context)
        "rainbows"
      end
    end
    uploaded_file = @uploader.upload(fakeio("image"), location: "foo")

    assert_equal "foo", uploaded_file.id
  end
end
