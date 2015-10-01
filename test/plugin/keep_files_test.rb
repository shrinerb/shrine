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
end
