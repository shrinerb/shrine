require "test_helper"
require "ostruct"

describe "the pretty_location plugin" do
  before do
    @uploader = uploader { plugin :pretty_location }
  end

  it "uses context to build the directory" do
    uploaded_file = @uploader.upload(fakeio, record: OpenStruct.new(id: 123), name: :avatar)

    assert_match %r{^openstruct/123/avatar/[\w-]+$}, uploaded_file.id
  end

  it "prepends version names to generated location" do
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"), version: :thumb)
    assert_match %r{^thumb-[\w-]+\.jpg$}, uploaded_file.id
  end
end
