require "test_helper"
require "shrine/plugins/data_uri"
require "dry-monitor"
require "base64"

describe Shrine::Plugins::DataUri do
  before do
    @attacher = attacher { plugin :data_uri }
    @shrine   = @attacher.shrine_class
  end

  describe "Attachment" do
    before do
      @model_class = model_class(:file_data)
    end

    describe "#<name>_data_uri=" do
      it "uploads the data URI to temporary storage" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file_data_uri = "data:image/png,content"

        assert_equal :cache,    model.file.storage_key
        assert_equal "content", model.file.read
      end

      it "is not defined on entity attachment" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file, model: false)

        refute @model_class.method_defined?(:file_data_uri=)
      end
    end

    describe "#<name>_data_uri" do
      it "returns assigned data URI" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file)

        model = @model_class.new
        model.file_data_uri = "data:image/png,content"

        assert_equal "data:image/png,content", model.file_data_uri
      end

      it "is not defined on entity attachment" do
        @shrine.plugin :model
        @model_class.include @shrine::Attachment.new(:file, model: false)

        refute @model_class.method_defined?(:file_data_uri)
      end
    end
  end

  describe "Shrine" do
    describe ".data_uri" do
      it "returns an IO-like object from the given data URI" do
        io = @shrine.data_uri("data:image/png,content")

        assert_instance_of StringIO, io.to_io
        assert_equal "image/png", io.content_type
        assert_equal "content", io.read
        assert_equal 7, io.size
        assert_equal true, io.eof?
        io.rewind
        assert_equal false, io.eof?
        io.close
      end

      it "extracts valid content type" do
        io = @shrine.data_uri("data:image/png,content")
        assert_equal "image/png", io.content_type

        io = @shrine.data_uri("data:application/vnd.api+json,content")
        assert_equal "application/vnd.api+json", io.content_type

        io = @shrine.data_uri("data:application/vnd.api+json;charset=utf-8,content")
        assert_equal "application/vnd.api+json;charset=utf-8", io.content_type

        assert_raises(Shrine::Plugins::DataUri::ParseError) do
          @shrine.data_uri("data:application/vnd.api&json,content")
        end

        io = @shrine.data_uri("data:,content")
        assert_equal "text/plain", io.content_type

        assert_raises(Shrine::Plugins::DataUri::ParseError) do
          @shrine.data_uri("data:content")
        end
      end

      it "URI-decodes raw content" do
        io = @shrine.data_uri("data:,raw%20content")
        assert_equal "raw content", io.read

        io = @shrine.data_uri("data:,raw content")
        assert_equal "raw content", io.read
      end

      it "handles base64 data URIs" do
        io = @shrine.data_uri("data:image/png;base64,#{Base64.encode64("content")}")
        assert_equal "image/png", io.content_type
        assert_equal "content",   io.read

        io = @shrine.data_uri("data:image/png;param=value;base64,#{Base64.encode64("content")}")
        assert_equal "image/png;param=value", io.content_type
        assert_equal "content",               io.read

        io = @shrine.data_uri("data:;base64,#{Base64.encode64("content")}")
        assert_equal "text/plain", io.content_type
        assert_equal "content",    io.read

        assert_raises(Shrine::Plugins::DataUri::ParseError) do
          @shrine.data_uri("data:base64,#{Base64.encode64("content")}")
        end
      end

      it "accepts data URIs with blank content" do
        io = @shrine.data_uri("data:,")
        assert_equal "", io.read
        assert_equal 0,  io.size
      end

      it "accepts :filename" do
        io = @shrine.data_uri("data:,content", filename: "foo.txt")
        assert_equal "foo.txt", io.original_filename
      end

      describe "with instrumentation" do
        before do
          @shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)
        end

        it "logs data URI parsing" do
          @shrine.plugin :data_uri

          assert_logged /^Data URI \(\d+ms\) – \{.+\}$/ do
            @shrine.data_uri("data:image/png,content")
          end
        end

        it "sends a data URI parsing event" do
          @shrine.plugin :data_uri

          @shrine.subscribe(:data_uri) { |event| @event = event }
          @shrine.data_uri("data:image/png,content")

          refute_nil @event
          assert_equal :data_uri,                @event.name
          assert_equal "data:image/png,content", @event[:data_uri]
          assert_equal @shrine,                  @event[:uploader]
          assert_kind_of Integer,                @event.duration
        end

        it "allows swapping log subscriber" do
          @shrine.plugin :data_uri, log_subscriber: -> (event) { @event = event }

          refute_logged /^Data URI/ do
            @shrine.data_uri("data:image/png,content")
          end

          refute_nil @event
        end

        it "allows disabling log subscriber" do
          @shrine.plugin :data_uri, log_subscriber: nil

          refute_logged /^Data URI/ do
            @shrine.data_uri("data:image/png,content")
          end
        end
      end
    end
  end

  describe "Attacher" do
    describe "#assign_data_uri" do
      it "uploads given data URI to temporary storage" do
        @attacher.assign_data_uri("data:image/png,content")

        assert @attacher.file
        assert_equal :cache, @attacher.file.storage_key
        assert @attacher.changed?

        assert_equal "content",   @attacher.file.read
        assert_equal "image/png", @attacher.file.mime_type
      end

      it "accepts additional uploader options" do
        @attacher.assign_data_uri("data:image/png,content", location: "foo")

        assert_equal "foo", @attacher.file.id
      end

      it "ignores empty strings" do
        file = @attacher.attach(fakeio)
        @attacher.assign_data_uri("")

        assert_equal file, @attacher.file
      end

      it "ignores nil values" do
        file = @attacher.attach(fakeio)
        @attacher.assign_data_uri(nil)

        assert_equal file, @attacher.file
      end

      it "adds validation error on parsing errors" do
        @attacher.assign_data_uri("bla")

        assert_equal ["data URI has invalid format"], @attacher.errors
      end

      it "clears any previous errors" do
        @attacher.errors << "foo"
        @attacher.assign_data_uri("bla")

        assert_equal ["data URI has invalid format"], @attacher.errors
      end
    end
  end

  describe "UploadedFile" do
    describe "#data_uri" do
      it "generates data URI from file content" do
        file = @attacher.upload(fakeio("content"))

        assert_equal "data:text/plain;base64,Y29udGVudA==", file.data_uri
      end

      it "uses existing MIME type" do
        file = @attacher.upload(fakeio("content"))
        file.metadata["mime_type"] = "image/jpeg"

        assert_equal "data:image/jpeg;base64,Y29udGVudA==", file.data_uri
      end
    end

    describe "#base64" do
      it "returns base64-encoded file content" do
        file = @attacher.upload(fakeio("content"))

        assert_equal "Y29udGVudA==", file.base64
      end
    end
  end
end
