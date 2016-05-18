require "test_helper"
require "tempfile"

describe "the parallelize plugin" do
  before do
    @uploader = uploader do
      plugin :versions, names: [:large, :medium, :small]
      plugin :parallelize
    end
  end

  it "successfully uploads" do
    versions = @uploader.upload(
      large:  fakeio("large"),
      medium: fakeio("medium"),
      small:  fakeio("small"),
    )
    assert_equal "large", versions[:large].read
    assert_equal "medium", versions[:medium].read
    assert_equal "small", versions[:small].read
  end

  it "successfully deletes" do
    @uploader.storage.instance_eval { undef multi_delete }
    versions = @uploader.upload(
      large:  fakeio("large"),
      medium: fakeio("medium"),
      small:  fakeio("small"),
    )
    @uploader.delete(versions)
    refute versions[:large].exists?
    refute versions[:medium].exists?
    refute versions[:small].exists?
  end

  it "works with moving plugin" do
    @uploader.class.plugin :moving
    memory_file = @uploader.upload(fakeio)
    uploaded_file = @uploader.upload(memory_file)
    assert uploaded_file.exists?
    refute memory_file.exists?
  end

  it "propagates any errors" do
    @uploader.storage.instance_eval { def upload(*); raise; end }
    assert_raises(RuntimeError) { @uploader.upload(fakeio) }
  end
end
