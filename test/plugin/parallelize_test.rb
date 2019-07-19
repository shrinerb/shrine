require "test_helper"
require "shrine/plugins/parallelize"
require "tempfile"
require "stringio"

describe Shrine::Plugins::Parallelize do
  before do
    @uploader = uploader do
      plugin :versions
      plugin :parallelize
    end
  end

  it "successfully uploads" do
    versions = @uploader.upload(
      large:  fakeio("large"),
      medium: fakeio("medium"),
      small:  fakeio("small"),
    )
    assert_equal "large", versions[:large].read
    assert_equal "medium", versions[:medium].read
    assert_equal "small", versions[:small].read
  end unless RUBY_ENGINE == "jruby"

  it "successfully deletes" do
    versions = @uploader.upload(
      large:  fakeio("large"),
      medium: fakeio("medium"),
      small:  fakeio("small"),
    )
    @uploader.delete(versions)
    refute versions[:large].exists?
    refute versions[:medium].exists?
    refute versions[:small].exists?
  end

  it "propagates any errors" do
    Thread.report_on_exception = false if Thread.respond_to?(:report_on_exception)
    @uploader.storage.instance_eval { def upload(*); raise; end }
    assert_raises(RuntimeError) { @uploader.upload(fakeio) }
    Thread.report_on_exception = true if Thread.respond_to?(:report_on_exception)
  end
end
