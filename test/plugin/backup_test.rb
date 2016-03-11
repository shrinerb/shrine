require "test_helper"

describe "the backup plugin" do
  before do
    @attacher = attacher { plugin :backup, storage: :cache }
  end

  def backup_file(uploaded_file)
    data = uploaded_file.data
    data["storage"] = @attacher.shrine_class.opts[:backup_storage].to_s
    @attacher.uploaded_file(data)
  end

  it "uploads to the backup storage on promoting and preserves location" do
    @attacher.assign(fakeio)
    @attacher._promote
    assert @attacher.get.exists?
    assert backup_file(@attacher.get).exists?
  end

  it "preserves location even when #generate_location is overriden" do
    @attacher.store.instance_eval { def generate_location(*); "foo"; end }
    @attacher.assign(fakeio)
    @attacher._promote
    refute_equal "foo", @attacher.get
  end

  it "still assigns the stored file" do
    @attacher.assign(fakeio)
    @attacher._promote
    assert_equal "store", @attacher.get.storage_key
  end

  it "deletes backed up files" do
    @attacher.assign(fakeio)
    @attacher._promote
    @attacher.destroy
    refute backup_file(@attacher.get).exists?
  end

  it "doesn't delete backed up file if :delete is set to false" do
    @attacher.shrine_class.opts[:backup_delete] = false
    @attacher.assign(fakeio)
    @attacher._promote
    @attacher.destroy
    assert backup_file(@attacher.get).exists?
  end

  describe "#backup_file" do
    it "returns the backed up uploaded file" do
      @attacher.assign(fakeio)
      @attacher._promote
      backup_file = @attacher.backup_file(@attacher.get)
      assert_equal "cache", backup_file.storage_key
    end

    it "doesn't modify the given uploaded file" do
      @attacher.assign(fakeio)
      @attacher._promote
      @attacher.backup_file(uploaded_file = @attacher.get)
      assert_equal @attacher.get, uploaded_file
    end
  end
end
