require "test_helper"
require "shrine/plugins/remote_url"
require "dry-monitor"

describe Shrine::Plugins::RemoteUrl do
  before do
    @attacher = attacher { plugin :remote_url, max_size: nil }
    @shrine   = @attacher.shrine_class

    Down.stubs(:download).with(good_url, max_size: nil).returns(StringIO.new("remote file"))
    Down.stubs(:download).with(bad_url, max_size: nil).raises(Down::NotFound.new("file not found"))
  end

  describe "Attachment" do
    before do
      @model_class = model_class(:file_data)
    end

    describe "#<name>_remote_url=" do
      it "assigns a remote URL" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file_remote_url = good_url

        assert_equal :cache,        model.file.storage_key
        assert_equal "remote file", model.file.read
      end

      it "is not defined for entity attachments" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file, model: false)

        refute @model_class.method_defined?(:file_remote_url=)
      end
    end

    describe "#<name>_remote_url" do
      it "returns assigned remote URL" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file_remote_url = good_url

        assert_equal good_url, model.file_remote_url
      end

      it "is not defined for entity attachments" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file, model: false)

        refute @model_class.method_defined?(:file_remote_url)
      end
    end
  end

  describe "Shrine" do
    describe ".remote_url" do
      it "downloads the file" do
        file = @shrine.remote_url(good_url)

        assert_equal "remote file", file.read
      end

      it "passes :max_size" do
        @shrine.plugin :remote_url, max_size: 1
        Down.expects(:download).with(good_url, max_size: 1).returns(StringIO.new("remote file"))

        file = @shrine.remote_url(good_url)

        assert_equal "remote file", file.read
      end

      it "uses :downloader" do
        @shrine.plugin :remote_url, downloader: -> (url, **) { fakeio(url) }

        file = @shrine.remote_url("foo")

        assert_equal "foo", file.read
      end

      it "re-raises Down::NotFound errors" do
        @shrine.plugin :remote_url, downloader: -> (url, **) { raise Down::NotFound }

        error = assert_raises Shrine::Plugins::RemoteUrl::DownloadError do
          @shrine.remote_url("foo")
        end

        assert_equal "remote file not found", error.message
      end

      it "re-raises Down::TooLarge errors" do
        @shrine.plugin :remote_url, downloader: -> (url, **) { raise Down::TooLarge }

        error = assert_raises Shrine::Plugins::RemoteUrl::DownloadError do
          @shrine.remote_url("foo")
        end

        assert_equal "remote file too large", error.message
      end

      it "re-raises DownloadError errors" do
        @shrine.plugin :remote_url, downloader: -> (url, **) { raise Shrine::Plugins::RemoteUrl::DownloadError, "custom message" }

        error = assert_raises Shrine::Plugins::RemoteUrl::DownloadError do
          @shrine.remote_url("foo")
        end

        assert_equal "custom message", error.message
      end

      it "propagates other exceptions" do
        @shrine.plugin :remote_url, downloader: -> (url, **) { raise KeyError }

        assert_raises KeyError do
          @shrine.remote_url("foo")
        end
      end

      describe "with instrumentation" do
        before do
          @shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)
        end

        it "logs remote URL download" do
          @shrine.plugin :remote_url

          assert_logged /^Remote URL \(\d+ms\) – \{.+\}$/ do
            @shrine.remote_url(good_url)
          end
        end

        it "sends a remote URL download event" do
          @shrine.plugin :remote_url

          @shrine.subscribe(:remote_url) { |event| @event = event }
          @shrine.remote_url(good_url)

          refute_nil @event
          assert_equal :remote_url,         @event.name
          assert_equal good_url,            @event[:remote_url]
          assert_equal Hash[max_size: nil], @event[:download_options]
          assert_equal @shrine,             @event[:uploader]
          assert_kind_of Integer,           @event.duration
        end

        it "allows swapping log subscriber" do
          @shrine.plugin :remote_url, log_subscriber: -> (event) { @event = event }

          refute_logged /^Remote URL/ do
            @shrine.remote_url(good_url)
          end

          refute_nil @event
        end

        it "allows disabling log subscriber" do
          @shrine.plugin :remote_url, log_subscriber: nil

          refute_logged /^Remote URL/ do
            @shrine.remote_url(good_url)
          end
        end
      end
    end
  end

  describe "Attacher" do
    describe "#assign_remote_url" do
      it "downloads remote file and attaches it to temporary storage" do
        @attacher.assign_remote_url(good_url)

        assert_equal :cache,        @attacher.file.storage_key
        assert_equal "remote file", @attacher.file.read
      end

      it "ignores empty urls" do
        file = @attacher.attach(fakeio)
        @attacher.assign_remote_url("")

        assert_equal file, @attacher.file
      end

      it "ignores nil values" do
        file = @attacher.attach(fakeio)
        @attacher.assign_remote_url(nil)

        assert_equal file, @attacher.file
      end

      it "accepts downloader options" do
        Down.expects(:download).with(good_url, max_size: nil, foo: "bar").returns(StringIO.new("remote file"))

        @attacher.assign_remote_url(good_url, downloader: { foo: "bar" })

        assert_equal "remote file", @attacher.file.read
      end

      it "forwards additional options to the uploader" do
        @attacher.assign_remote_url(good_url, location: "foo")

        assert_equal "foo", @attacher.file.id
      end

      describe "on download error" do
        it "aborts assignment" do
          @attacher.assign_remote_url(bad_url)

          assert_nil @attacher.file
        end

        it "adds validation errors" do
          @attacher.assign_remote_url(good_url)
          assert_empty @attacher.errors

          @attacher.assign_remote_url(bad_url)
          assert_equal ["download failed: remote file not found"], @attacher.errors

          Down.stubs(:download).with(bad_url, max_size: nil).raises(Down::TooLarge.new("file is too large"))
          @attacher.assign_remote_url(bad_url)
          assert_equal ["download failed: remote file too large"], @attacher.errors
        end

        it "accepts custom validation error message" do
          @shrine.plugin :remote_url, error_message: "download failed"
          @attacher.assign_remote_url(bad_url)
          assert_equal ["download failed"], @attacher.errors

          @shrine.plugin :remote_url, error_message: -> (url) { "download failed: #{url}" }
          @attacher.assign_remote_url(bad_url)
          assert_equal ["download failed: #{bad_url}"], @attacher.errors

          @shrine.plugin :remote_url, error_message: -> (url, error) { error.message }
          @attacher.assign_remote_url(bad_url)
          assert_equal ["remote file not found"], @attacher.errors
        end

        it "clears any previous errors" do
          @attacher.errors << "foo"
          @attacher.assign_remote_url(bad_url)

          refute_includes @attacher.errors, "foo"
        end
      end
    end
  end

  def good_url
    "http://example.com/good.jpg"
  end

  def bad_url
    "http://example.com/bad.jpg"
  end
end
