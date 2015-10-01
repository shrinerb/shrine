require "test_helper"
require "ostruct"

describe "pretty_location plugin" do
  before do
    @uploader = uploader { plugin :pretty_location }
  end

  it "uses context to build the directory" do
    uploaded_file = @uploader.upload(fakeio, record: OpenStruct.new(id: 123), name: :avatar)

    assert_match %r{^openstruct/123/avatar/[\w-]+$}, uploaded_file.id
  end

  it "prepends version names to generated location" do
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"), version: :thumb)
    assert_match %r{^thumb-[\w-]+.jpg$}, uploaded_file.id
  end

  it "works with preserve_filename" do
    @uploader = uploader do
      plugin :preserve_filename
      plugin :pretty_location
    end

    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"), version: :thumb, name: :avatar)

    assert_match %r{^avatar/[\w-]+/thumb-foo\.jpg$}, uploaded_file.id
  end
end
