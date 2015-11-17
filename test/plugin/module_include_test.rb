require "test_helper"

describe "the module_include plugin" do
  before do
    @uploader = uploader { plugin :module_include }
  end

  it "allows including module to Attachment" do
    @uploader.class.attachment_module { def some_method; end }

    assert_includes @uploader.class::Attachment.instance_methods, :some_method
  end

  it "allows including module to Attacher" do
    @uploader.class.attacher_module { def some_method; end }

    assert_includes @uploader.class::Attacher.instance_methods, :some_method
  end

  it "allows including module to UploadedFile" do
    @uploader.class.file_module { def some_method; end }

    assert_includes @uploader.class::UploadedFile.instance_methods, :some_method
  end

  it "works with a module instead of a block" do
    @uploader.class.file_module Module.new { def some_method; end }

    assert_includes @uploader.class::UploadedFile.instance_methods, :some_method
  end
end
