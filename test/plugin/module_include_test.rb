require "test_helper"

describe "the module_include plugin" do
  before do
    @uploader = uploader { plugin :module_include }
  end

  it "allows including module to Attachment" do
    @uploader.class.attachment_module { def one; end }
    @uploader.class.attachment_module Module.new { def two; end }
    assert_includes @uploader.class::Attachment.instance_methods, :one
    assert_includes @uploader.class::Attachment.instance_methods, :two
  end

  it "allows including module to Attacher" do
    @uploader.class.attacher_module { def one; end }
    @uploader.class.attacher_module Module.new { def two; end }
    assert_includes @uploader.class::Attacher.instance_methods, :one
    assert_includes @uploader.class::Attacher.instance_methods, :two
  end

  it "allows including module to UploadedFile" do
    @uploader.class.file_module { def one; end }
    @uploader.class.file_module Module.new { def two; end }
    assert_includes @uploader.class::UploadedFile.instance_methods, :one
    assert_includes @uploader.class::UploadedFile.instance_methods, :two
  end
end
