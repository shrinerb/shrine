require "test_helper"
require "shrine/plugins/keep_files"

describe Shrine::Plugins::KeepFiles do
  before do
    @attacher = attacher { plugin :keep_files }
  end

  describe "Attacher" do
    describe "#destroy_attached" do
      it "keeps files" do
        @attacher.attach(fakeio)
        @attacher.destroy_attached

        assert @attacher.file.exists?
      end
    end

    describe "#destroy_previous" do
      it "keep files" do
        previous_file = @attacher.attach(fakeio)
        @attacher.attach(fakeio)
        @attacher.destroy_previous

        assert previous_file.exists?
      end
    end
  end
end
