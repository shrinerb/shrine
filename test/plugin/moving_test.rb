require "test_helper"
require "shrine/plugins/moving"
require "shrine/storage/file_system"

describe Shrine::Plugins::Moving do
  before do
    @uploader = uploader { plugin :moving }
  end

  it "moves the IO using the storage" do
    memory_file = @uploader.upload(fakeio)
    uploaded_file = @uploader.upload(memory_file)
    assert uploaded_file.exists?
    refute memory_file.exists?
  end

  it "allows specifying storages" do
    @uploader.opts[:moving_storages] = []
    memory_file = @uploader.upload(fakeio)
    uploaded_file = @uploader.upload(memory_file)
    assert uploaded_file.exists?
    assert memory_file.exists?
  end

  it "doesn't move if storage doesn't support moving" do
    @uploader.storage.instance_eval { undef move }
    memory_file = @uploader.upload(fakeio)
    uploaded_file = @uploader.upload(memory_file)
    assert uploaded_file.exists?
    assert memory_file.exists?
  end

  it "doesn't move if IO isn't movable" do
    @uploader.storage.instance_eval { def movable?(*); false; end }
    memory_file = @uploader.upload(fakeio)
    uploaded_file = @uploader.upload(memory_file)
    assert uploaded_file.exists?
    assert memory_file.exists?
  end
end
