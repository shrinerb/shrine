require "test_helper"

describe "the backup plugin" do
  before do
    @attacher = attacher { plugin :backup, storage: :cache }
  end

  it "uploads to the backup storage on storing" do
    @attacher.assign(fakeio)
    @attacher._promote

    assert @attacher.get.exists?
    assert @attacher.backup_file(@attacher.get).exists?
  end

  it "deletes the backed up file" do
    @attacher.assign(fakeio)
    @attacher._promote
    @attacher.destroy

    refute @attacher.backup_file(@attacher.get).exists?
  end

  it "doesn't delete backed up file if :delete is set to false" do
    @attacher.shrine_class.opts[:backup_delete] = false

    @attacher.assign(fakeio)
    @attacher._promote
    @attacher.destroy

    assert @attacher.backup_file(@attacher.get).exists?
  end
end
