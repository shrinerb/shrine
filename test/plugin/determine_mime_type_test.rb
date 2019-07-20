require "test_helper"
require "shrine/plugins/determine_mime_type"
require "stringio"
require "open3"
require "dry-monitor"

describe Shrine::Plugins::DetermineMimeType do
  before do
    @uploader = uploader { plugin :determine_mime_type }
    @shrine = @uploader.class
  end

  describe ":file analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :file
    end

    it "determines MIME type from file contents" do
      assert_equal "image/jpeg", @shrine.determine_mime_type(image)
    end

    it "returns text/plain for unidentified MIME types" do
      assert_equal "text/plain", @shrine.determine_mime_type(fakeio("a" * 5*1024*1024))
    end

    it "is able to determine MIME type for non-files" do
      assert_equal "image/jpeg", @shrine.determine_mime_type(fakeio(image.read))
    end

    it "returns nil for empty IOs" do
      assert_nil @shrine.determine_mime_type(fakeio(""))
    end

    it "raises error if file command is not found" do
      Open3.stubs(:popen3).raises(Errno::ENOENT)
      exception = assert_raises(Shrine::Error) { @shrine.determine_mime_type(fakeio) }
      assert_equal "file command-line tool is not installed", exception.message
    end

    it "raises error if file command failed" do
      failed_result = Open3.popen3("file", "--foo")
      Open3.stubs(:popen3).yields(failed_result)
      exception = assert_raises(Shrine::Error) { @shrine.determine_mime_type(fakeio) }
      assert_match "file command failed: ", exception.message
    end

    it "raises error if file command failed to spawn" do
      Open3.expects(:popen3).yields(StringIO.new, StringIO.new, StringIO.new, Thread.new {})
      exception = assert_raises(Shrine::Error) { @shrine.determine_mime_type(fakeio("d")) }
      assert_match "file command failed to spawn: ", exception.message
    end

    it "raises error if file command couldn't open file" do
      result = Open3.popen3("file", "--version")
      result[1] = StringIO.new("cannot open: No such file or directory") # stdout
      Open3.expects(:popen3).yields(result)
      exception = assert_raises(Shrine::Error) { @shrine.determine_mime_type(fakeio("d")) }
      assert_match "file command failed: cannot open: No such file or directory", exception.message
    end

    it "fowards any warnings to stderr" do
      assert_output(nil, "") { @shrine.determine_mime_type(image) }

      stderr_result = Open3.popen3("echo stderr 1>&2")
      Open3.stubs(:popen3).yields(stderr_result)
      assert_output(nil, "stderr\n") { @shrine.determine_mime_type(image) }
    end
  end

  describe ":fastimage analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :fastimage
    end

    it "extracts MIME type of any IO" do
      assert_equal "image/jpeg", @shrine.determine_mime_type(image)
    end

    it "returns nil for unidentified MIME types" do
      assert_nil @shrine.determine_mime_type(fakeio("😃"))
    end

    it "returns nil for empty IOs" do
      assert_nil @shrine.determine_mime_type(fakeio(""))
    end
  end

  describe ":filemagic analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :filemagic
    end

    it "determines MIME type from file contents" do
      assert_equal "image/jpeg", @shrine.determine_mime_type(image)
    end

    it "returns text/plain for unidentified MIME types" do
      assert_equal "text/plain", @shrine.determine_mime_type(fakeio("😃"))
    end

    it "returns nil for empty IOs" do
      assert_nil @shrine.determine_mime_type(fakeio(""))
    end
  end unless RUBY_ENGINE == "jruby" || ENV["CI"]

  describe ":mimemagic analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :mimemagic
    end

    it "extracts MIME type of any IO" do
      assert_equal "image/jpeg", @shrine.determine_mime_type(image)
    end

    it "returns nil for unidentified MIME types" do
      assert_nil @shrine.determine_mime_type(fakeio("😃"))
    end

    it "returns nil for empty IOs" do
      assert_nil @shrine.determine_mime_type(fakeio(""))
    end
  end

  describe ":marcel analyzer" do
    describe "no options" do
      before do
        @shrine.plugin :determine_mime_type, analyzer: :marcel
      end

      it "extracts MIME type of any IO" do
        assert_equal "image/jpeg", @shrine.determine_mime_type(image)
      end

      it "returns application/octet-stream for unidentified MIME types" do
        assert_equal "application/octet-stream", @shrine.determine_mime_type(fakeio("😃"))
      end

      it "returns nil for empty IOs" do
        assert_nil @shrine.determine_mime_type(fakeio(""))
      end
    end

    describe "with options" do
      it "extracts MIME type of any IO" do
        @shrine.plugin :determine_mime_type, analyzer: :marcel, analyzer_options: { filename_fallback: false }
        assert_equal "image/jpeg", @shrine.determine_mime_type(image)
      end

      it "returns application/octet-stream for unidentified MIME types" do
        @shrine.plugin :determine_mime_type, analyzer: :marcel, analyzer_options: { filename_fallback: false }
        assert_equal "application/octet-stream", @shrine.determine_mime_type(fakeio("😃", filename: "smile.jpeg"))
      end

      it "returns the MIME type based on filename for unidentified MIME types when using filename fallback" do
        @shrine.plugin :determine_mime_type, analyzer: :marcel, analyzer_options: { filename_fallback: true }
        assert_equal "image/jpeg", @shrine.determine_mime_type(fakeio("😃", filename: "smile.jpeg"))
      end
    end
  end

  describe ":mime_types analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :mime_types
    end

    it "extract MIME type from the file extension" do
      assert_equal "image/png", @shrine.determine_mime_type(fakeio(filename: "image.png"))
      assert_equal "image/jpeg", @shrine.determine_mime_type(image)
    end

    it "extracts MIME type from file extension when IO is empty" do
      assert_equal "image/png", @shrine.determine_mime_type(fakeio("", filename: "image.png"))
    end

    it "returns nil on unknown extension" do
      assert_nil @shrine.determine_mime_type(fakeio(filename: "file.foo"))
    end

    it "returns nil when input is not a file" do
      assert_nil @shrine.determine_mime_type(fakeio)
    end
  end

  describe ":mini_mime analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :mini_mime
    end

    it "extract MIME type from the file extension" do
      assert_equal "image/png", @shrine.determine_mime_type(fakeio(filename: "image.png"))
      assert_equal "image/jpeg", @shrine.determine_mime_type(image)
    end

    it "extracts MIME type from file extension when IO is empty" do
      assert_equal "image/png", @shrine.determine_mime_type(fakeio("", filename: "image.png"))
    end

    it "returns nil on unkown extension" do
      assert_nil @shrine.determine_mime_type(fakeio(filename: "file.foo"))
    end

    it "returns nil when input is not a file" do
      assert_nil @shrine.determine_mime_type(fakeio)
    end
  end

  describe ":content_type analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :content_type
    end

    it "extracts MIME type from #content_type" do
      assert_equal "foo/bar", @shrine.determine_mime_type(fakeio(content_type: "foo/bar"))
    end

    it "strips away any media type parameters" do
      assert_equal "foo/bar", @shrine.determine_mime_type(fakeio(content_type: "foo/bar; param=value"))
    end

    it "returns nil when #content_type is nil" do
      assert_nil @shrine.determine_mime_type(fakeio(content_type: nil))
    end

    it "returns nil when IO doesn't respond to #content_type" do
      assert_nil @shrine.determine_mime_type(image)
    end
  end

  describe "with instrumentation" do
    before do
      @shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)
    end

    it "logs MIME type extraction" do
      @shrine.plugin :determine_mime_type

      assert_logged /^MIME Type \(\d+ms\) – \{.+\}$/ do
        @shrine.determine_mime_type(image)
      end
    end

    it "sends a MIME type extraction event" do
      @shrine.plugin :determine_mime_type

      @shrine.subscribe(:mime_type) { |event| @event = event }
      @shrine.determine_mime_type(io = image)

      refute_nil @event
      assert_equal :mime_type, @event.name
      assert_equal io,         @event[:io]
      assert_equal @shrine,    @event[:uploader]
      assert_kind_of Integer,  @event.duration
    end

    it "allows swapping log subscriber" do
      @shrine.plugin :determine_mime_type, log_subscriber: -> (event) { @event = event }

      refute_logged /^MIME Type/ do
        @shrine.determine_mime_type(image)
      end

      refute_nil @event
    end

    it "allows disabling log subscriber" do
      @shrine.plugin :determine_mime_type, log_subscriber: nil

      refute_logged /^MIME Type/ do
        @shrine.determine_mime_type(image)
      end
    end
  end

  it "automatically extracts mime type on upload" do
    uploaded_file = @uploader.upload(image)
    assert_equal "image/jpeg", uploaded_file.metadata["mime_type"]
  end

  it "has a default analyzer" do
    assert_equal "image/jpeg", @shrine.determine_mime_type(fakeio(image.read))
  end

  it "allows passing a custom extractor" do
    @shrine.plugin :determine_mime_type, analyzer: ->(io) { "foo/bar" }
    assert_equal "foo/bar", @shrine.determine_mime_type(image)

    @shrine.plugin :determine_mime_type, analyzer: ->(io, analyzers) { analyzers[:file].call(io) }
    assert_equal "image/jpeg", @shrine.determine_mime_type(image)
  end

  it "always rewinds the file" do
    @shrine.plugin :determine_mime_type, analyzer: ->(io) { io.read }
    @shrine.determine_mime_type(file = image)
    assert_equal 0, file.pos
  end

  it "provides access to mime type analyzers" do
    analyzers = @shrine.mime_type_analyzers

    mime_type = analyzers[:file].call(io = fakeio("content", filename: "file.json"))
    assert_equal "text/plain", mime_type
    assert_equal "content", io.read

    mime_type = analyzers[:mime_types].call(io = fakeio("content", filename: "file.json"))
    assert_equal "application/json", mime_type
    assert_equal "content", io.read

    mime_type = analyzers[:content_type].call(io = fakeio("content", content_type: "foo/bar"))
    assert_equal "foo/bar", mime_type
    assert_equal "content", io.read

    mime_type = analyzers[:marcel].call(io = fakeio("content", filename: "file.json"), filename_fallback: false)
    assert_equal "application/octet-stream", mime_type
    assert_equal "content", io.read

    mime_type = analyzers[:marcel].call(io = fakeio("content", filename: "file.json"), filename_fallback: true)
    assert_equal "application/json", mime_type
    assert_equal "content", io.read
  end

  it "has .mime_type alias" do
    assert_equal "image/jpeg", @shrine.mime_type(image)
  end

  it "returns Shrine::Error on unknown analyzer" do
    assert_raises Shrine::Error do
      @shrine.plugin :determine_mime_type, analyzer: :foo
      @shrine.determine_mime_type(fakeio)
    end
  end
end
