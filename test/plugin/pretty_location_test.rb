require "test_helper"
require "ostruct"

describe "the pretty_location plugin" do
  before do
    @uploader = uploader { plugin :pretty_location }
  end

  it "uses context to build the directory" do
    uploaded_file = @uploader.upload(fakeio, record: OpenStruct.new(id: 123), name: :avatar)

    assert_match %r{\Aopenstruct/123/avatar/[\w-]+\z}, uploaded_file.id
  end

  it "prepends version names to generated location" do
    uploaded_file = @uploader.upload(fakeio(filename: "foo.jpg"), version: :thumb)
    assert_match %r{\Athumb-[\w-]+\.jpg\z}, uploaded_file.id
  end

  it "appends a 10 character alphanumeric string suffix" do
    uploaded_file = @uploader.upload(fakeio(filename: "bar.png"), version: :square)
    assert_match %r{\Asquare-[a-z0-9]{10}+\.png\z}, uploaded_file.id
  end
end
