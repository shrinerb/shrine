require "test_helper"
require "tempfile"
require "stringio"

describe "the parallelize plugin" do
  before do
    @uploader = uploader do
      plugin :versions, names: [:large, :medium, :small]
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
  end

  it "successfully deletes" do
    @uploader.storage.instance_eval { undef multi_delete }
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

  it "works with moving plugin" do
    @uploader = uploader do
      plugin :parallelize
      plugin :moving
    end

    memory_file = @uploader.upload(fakeio)
    uploaded_file = @uploader.upload(memory_file)
    assert uploaded_file.exists?
    refute memory_file.exists?
  end

  it "works with logging plugin" do
    @uploader = uploader do
      plugin :logging, stream: StringIO.new
      plugin :parallelize
    end

    @uploader.instance_eval do
      def with_pool(*)
        super
        opts[:logging_stream].puts("pool performed")
      end
    end

    @uploader.upload(fakeio)
    assert_match "pool performed", @uploader.opts[:logging_stream].string.lines[0]
    assert_match "STORE",          @uploader.opts[:logging_stream].string.lines[1]
  end

  it "propagates any errors" do
    @uploader.storage.instance_eval { def upload(*); raise; end }
    assert_raises(RuntimeError) { @uploader.upload(fakeio) }
  end
end
