require "test_helper"
require "shrine/plugins/module_include"

describe Shrine::Plugins::ModuleInclude do
  before do
    @shrine = shrine { plugin :module_include }
  end

  describe "Shrine" do
    describe ".attachment_module" do
      it "includes module into Attachment" do
        @shrine.attachment_module { def one; end }
        @shrine.attachment_module Module.new { def two; end }
        assert_includes @shrine::Attachment.instance_methods, :one
        assert_includes @shrine::Attachment.instance_methods, :two
      end
    end

    describe ".attacher_module" do
      it "includes module into Attacher" do
        @shrine.attacher_module { def one; end }
        @shrine.attacher_module Module.new { def two; end }
        assert_includes @shrine::Attacher.instance_methods, :one
        assert_includes @shrine::Attacher.instance_methods, :two
      end
    end

    describe ".file_module" do
      it "includes module into UploadedFile" do
        @shrine.file_module { def one; end }
        @shrine.file_module Module.new { def two; end }
        assert_includes @shrine::UploadedFile.instance_methods, :one
        assert_includes @shrine::UploadedFile.instance_methods, :two
      end
    end
  end
end
