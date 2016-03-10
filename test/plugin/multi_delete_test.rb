require "test_helper"

describe "multi_delete plugin" do
  before do
    @uploader = uploader { plugin :multi_delete }
  end

  it "allows deleting multiple files at instance level" do
    uploaded_file = @uploader.upload(fakeio)
    deleted_files = @uploader.delete([uploaded_file])
    assert_equal [uploaded_file], deleted_files
    assert deleted_files.none?(&:exists?)
  end

  it "calls multi_delete if storage supports it" do
    @uploader.storage.expects(:multi_delete).with(["foo"])
    uploaded_file = @uploader.upload(fakeio, location: "foo")
    deleted_files = @uploader.delete([uploaded_file])
    assert_equal [uploaded_file], deleted_files
  end
end
