require "test_helper"
require "shrine/plugins/tempfile"

describe Shrine::Plugins::Tempfile do
  before do
    @uploader = uploader { plugin :tempfile }
    @shrine = @uploader.class
  end

  it "downloads the content to tempfile on first call" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.open do
      tempfile = uploaded_file.tempfile
      assert_instance_of Tempfile, tempfile
      assert_equal "content", tempfile.read
    end
  end

  it "returns the same tempfile on subsequent calls" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.open do
      assert_equal uploaded_file.tempfile, uploaded_file.tempfile
    end
  end

  it "deletes the tempfile at the end of the open block" do
    uploaded_file = @uploader.upload(fakeio("content"))
    tempfile = uploaded_file.open { uploaded_file.tempfile }
    assert tempfile.closed?
    assert_nil tempfile.path
  end

  it "deletes the tempfile when uploaded file is closed explicitly" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.open
    tempfile = uploaded_file.tempfile
    uploaded_file.close
    assert tempfile.closed?
    assert_nil tempfile.path
  end

  it "rewinds the tempfile" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.open do
      uploaded_file.tempfile.read
      assert_equal 0, uploaded_file.tempfile.pos
    end
  end

  it "raises an error when uploaded file is not open" do
    uploaded_file = @uploader.upload(fakeio("content"))
    assert_raises(Shrine::Error) { uploaded_file.tempfile }
  end

  it "allows caching the tempfile again" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.open do
      assert_equal "content", uploaded_file.tempfile.read
    end
    uploaded_file.open do
      assert_equal "content", uploaded_file.tempfile.read
    end
  end

  describe "Shrine.with_file" do
    it "yields an open tempfile reference" do
      uploaded_file = @uploader.upload(fakeio("content"))
      uploaded_file.open do
        file = @shrine.with_file(uploaded_file) do |file|
          assert_equal uploaded_file.tempfile.path, file.path
          refute_equal uploaded_file.tempfile.fileno, file.fileno
          assert file.binmode?
          refute file.closed?
          file
        end
        assert file.closed?
      end

      # calls #download when uploaded file is not opened
      path1, path2 = nil
      @shrine.with_file(uploaded_file) { |file| path1 = file.path }
      @shrine.with_file(uploaded_file) { |file| path2 = file.path }
      refute_equal path1, path2
    end

    it "works with non-opened uploaded files" do
      uploaded_file = @uploader.upload(fakeio("content"))
      @shrine.with_file(uploaded_file) do |file|
        File.exist?(file.path)
        assert_equal "content", file.read
      end
    end
  end
end
