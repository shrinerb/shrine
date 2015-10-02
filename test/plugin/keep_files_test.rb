require "test_helper"

describe "keep_files plugin" do
  def attacher(options = {})
    super() { plugin :keep_files, options }
  end

  describe ":destroyed" do
    it "keeps files which are deleted on destroy" do
      @attacher = attacher(destroyed: true)
      uploaded_file = @attacher.set(fakeio)

      @attacher.destroy

      assert uploaded_file.exists?
    end
  end

  describe ":replaced" do
    it "keeps files which were replaced during saving" do
      @attacher = attacher(replaced: true)
      uploaded_file = @attacher.set(fakeio)
      @attacher.set(fakeio)
      @attacher.replace

      assert uploaded_file.exists?

      uploaded_file = @attacher.get
      @attacher.set(nil)
      @attacher.replace

      assert uploaded_file.exists?
    end
  end

  describe ":cached" do
    it "keeps cached files which were promoted" do
      @attacher = attacher(cached: true)
      cached_file = @attacher.set(fakeio)
      @attacher.promote(cached_file)

      refute_equal cached_file, @attacher.get
      assert cached_file.exists?
    end
  end

  it "works with background_delete plugin" do
    @attacher = attacher(destroyed: true, replaced: true, cached: true)
    @attacher.shrine_class.plugin :background_delete do |cached_file, context|
      @attacher.shrine_class.delete(cached_file, context)
    end

    cached_file = @attacher.set(fakeio)
    @attacher.promote(fakeio)
    assert cached_file.exists?

    replaced_file = @attacher.get
    @attacher.set(fakeio)
    @attacher.replace
    assert replaced_file.exists?

    destroyed_file = @attacher.get
    @attacher.destroy
    assert destroyed_file.exists?
  end
end
