require "test_helper"

describe "the keep_files plugin" do
  describe ":destroyed" do
    before do
      @attacher = attacher do
        plugin :keep_files, destroyed: true
      end
    end

    it "keeps files which are deleted on destroy" do
      @attacher.set(@attacher.store.upload(fakeio))
      @attacher.destroy
      assert @attacher.get.exists?
    end
  end

  describe ":replaced" do
    before do
      @attacher = attacher do
        plugin :keep_files, replaced: true
      end
    end

    it "keeps files which were replaced during saving" do
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

  it "works with backgrounding plugin" do
    @attacher = attacher do
      plugin :keep_files, destroyed: true, replaced: true
    end

    @attacher.shrine_class.plugin :backgrounding
    @attacher.class.delete { |data| self.class.delete(data)  }
    @attacher.class.promote { |data| self.class.promote(data) }

    @attacher.set(uploaded_file = @attacher.store.upload(fakeio))
    @attacher.set(nil)
    @attacher.replace
    assert uploaded_file.exists?

    @attacher.set(uploaded_file = @attacher.store.upload(fakeio))
    @attacher.destroy
    assert uploaded_file.exists?
  end
end
