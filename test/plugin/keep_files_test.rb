require "test_helper"

describe "the keep_files plugin" do
  def attacher(options = {})
    super() { plugin :keep_files, options }
  end

  describe ":destroyed" do
    it "keeps files which are deleted on destroy" do
      @attacher = attacher(destroyed: true)
      @attacher.set(@attacher.store.upload(fakeio))

      @attacher.destroy

      assert @attacher.get.exists?
    end
  end

  describe ":replaced" do
    it "keeps files which were replaced during saving" do
      @attacher = attacher(replaced: true)
      uploaded_file = @attacher.set(@attacher.store.upload(fakeio))
      @attacher.set(@attacher.store.upload(fakeio))
      @attacher.replace

      assert uploaded_file.exists?

      uploaded_file = @attacher.get
      @attacher.assign(nil)
      @attacher.replace

      assert uploaded_file.exists?
    end
  end

  it "works with background_helpers plugin" do
    @attacher = attacher(destroyed: true, replaced: true)
    @attacher.shrine_class.plugin :background_helpers
    @attacher.class.delete { |data| self.class.delete(data)  }
    @attacher.class.promote { promote(get) }

    replaced_file = @attacher.set(@attacher.store.upload(fakeio))
    @attacher.set(@attacher.store.upload(fakeio))
    @attacher.replace
    assert replaced_file.exists?

    destroyed_file = @attacher.get
    @attacher.destroy
    assert destroyed_file.exists?
  end
end
