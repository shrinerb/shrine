require "test_helper"

describe "multi_delete plugin" do
  before do
    @uploader = uploader { plugin :multi_delete }
  end

  it "allows Shrine#delete to take multiple files" do
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

  it "does regular individual deletion if storage doesn't support it" do
    @uploader.storage.instance_eval { undef multi_delete }
    uploaded_file = @uploader.upload(fakeio)
    deleted_files = @uploader.delete([uploaded_file])
    assert_equal [uploaded_file], deleted_files
    assert deleted_files.none?(&:exists?)
  end
end
