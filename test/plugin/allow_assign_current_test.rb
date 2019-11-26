require "test_helper"
require "shrine/plugins/allow_assign_current"

describe Shrine::Plugins::AllowAssignCurrent do
  before do
    @attacher = attacher { plugin :allow_assign_current }
    @shrine   = @attacher.shrine_class
  end

  it "ignores assigning current non-cached file" do
    file = @attacher.upload(fakeio, :other_store)
    @attacher.file = file
    @attacher.assign(file.to_json)
    assert_equal file , @attacher.file
  end

  it "doesn't use any metadata when skipping" do
    file = @attacher.upload(fakeio, :other_store)
    @attacher.file = file
    @attacher.assign(id: file.id, storage: file.storage_key, metadata: { "foo" => "bar" })
    refute @attacher.file.metadata.key?("foo")
  end

  it "still allows assigning new cached files" do
    file = @attacher.upload(fakeio, :cache)
    @attacher.assign(file.to_json)
    assert_equal file, @attacher.file
  end

  it "still raises exception for other non-cached files" do
    file = @attacher.upload(fakeio)
    assert_raises(Shrine::Error) do
      @attacher.assign(file.to_json)
    end
  end

  it "still properly rejects empty strings" do
    @attacher.assign("")
    assert_nil @attacher.file
  end

  it "doesn't let restore_cached_data plugin refresh metadata" do
    @shrine.plugin :restore_cached_data
    file = @attacher.upload(fakeio)
    @attacher.file = file
    @shrine::UploadedFile.any_instance.expects(:refresh_metadata!).never
    @attacher.assign(file.to_json)
  end
end
