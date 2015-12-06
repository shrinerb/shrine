require "test_helper"

describe "the backup plugin" do
  before do
    @attacher = attacher { plugin :backup, storage: :cache }
  end

  it "uploads to the backup storage on storing" do
    @attacher.assign(fakeio)
    @attacher._promote

    assert @attacher.get.exists?

    backed_up_file = @attacher.get
    backed_up_file.data["storage"] = "cache"

    assert backed_up_file.exists?
  end
end
