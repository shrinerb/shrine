require "test_helper"

describe "parallelize plugin" do
  before do
    @uploader = uploader do
      plugin :versions, names: [:large, :medium, :small]
      plugin :parallelize
    end
  end

  it "uploads in parallel" do
    versions = @uploader.upload(
      large:  fakeio("large"),
      medium: fakeio("medium"),
      small:  fakeio("small"),
    )

    assert_equal "large", versions[:large].read
    assert_equal "medium", versions[:medium].read
    assert_equal "small", versions[:small].read
  end

  it "deletes in parallel" do
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
end
