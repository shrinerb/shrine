require "test_helper"
require "shrine/plugins/instrumentation"
require "active_support/notifications"
require "dry-monitor"

describe Shrine::Plugins::Instrumentation do
  before do
    @notifications = Dry::Monitor::Notifications.new(:test)
    @shrine = shrine
    @shrine.plugin :instrumentation, notifications: @notifications, log_events: []
  end

  after do
    # clear all subscribers
    ActiveSupport::Notifications.notifier = ActiveSupport::Notifications::Fanout.new
  end

  describe "Shrine" do
    describe ".instrument" do
      before do
        @shrine = shrine { plugin :instrumentation }
      end

      it "sends notification to default notifications" do
        ActiveSupport::Notifications.subscribe("my_event.shrine") do |*args|
          @event = ActiveSupport::Notifications::Event.new(*args)
        end

        @shrine.instrument(:my_event, foo: "bar") {}

        assert_instance_of ActiveSupport::Notifications::Event, @event
        assert_equal "bar", @event.payload[:foo]
        assert_instance_of Float, @event.duration
      end

      it "sends notification to ActiveSupport::Notifications" do
        @shrine.plugin :instrumentation, notifications: ActiveSupport::Notifications

        ActiveSupport::Notifications.subscribe("my_event.shrine") do |*args|
          @event = ActiveSupport::Notifications::Event.new(*args)
        end

        @shrine.instrument(:my_event, foo: "bar") {}

        assert_instance_of ActiveSupport::Notifications::Event, @event
        assert_equal "bar", @event.payload[:foo]
        assert_instance_of Float, @event.duration
      end

      it "sends notification to Dry::Monitor::Notifications" do
        notifications = Dry::Monitor::Notifications.new(:test)
        notifications.register_event("my_event.shrine")

        @shrine.plugin :instrumentation, notifications: notifications

        notifications.subscribe("my_event.shrine") { |event| @event = event }
        @shrine.instrument(:my_event, foo: "bar") {}

        assert_instance_of Dry::Events::Event, @event
        assert_equal "bar",                    @event[:foo]
        assert_kind_of Integer,                @event[:time]
      end
    end

    describe ".subscribe" do
      it "yields events for dry-monitor" do
        @shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)
        @shrine.subscribe(:my_event) { |event| @event = event }
        @shrine.instrument(:my_event, foo: "bar") {}

        refute_nil @event
        assert_equal :my_event,             @event.name
        assert_equal "bar",                 @event[:foo]
        assert_equal %i[foo time uploader], @event.payload.keys.sort
        assert_kind_of Integer,             @event.duration
      end

      it "yields events for ActiveSupport::Notifications" do
        @shrine.plugin :instrumentation, notifications: ActiveSupport::Notifications
        @shrine.subscribe(:my_event) { |event| @event = event }
        @shrine.instrument(:my_event, foo: "bar") {}

        refute_nil @event
        assert_equal :my_event,        @event.name
        assert_equal "bar",            @event[:foo]
        assert_equal %i[foo uploader], @event.payload.keys.sort
        assert_kind_of Integer,        @event.duration
      end

      it "only subscribes to events from shrine class descendants" do
        @shrine.subscribe(:my_event) { |event| @event = event }
        subclass_1 = Class.new(@shrine)
        subclass_2 = Class.new(@shrine)
        subclass_2.subscribe(:my_event) { |event| @sub_event = event }

        subclass_1.instrument(:my_event) {}
        refute_nil @event
        assert_nil @sub_event
      end

      it "doesn't allow duplicate subscribers" do
        subscriber_calls = 0
        subscriber = -> (event) { subscriber_calls += 1 }
        @shrine.subscribe(:my_event, &subscriber)
        @shrine.subscribe(:my_event, &subscriber)

        @shrine.instrument(:my_event, foo: "bar") {}

        assert_equal 1, subscriber_calls
      end

      it "allows duplicates across subclasses" do
        called = []
        subscriber = -> (event) { called << event[:uploader] }
        subclass_1 = Class.new(@shrine)
        subclass_1.subscribe(:my_event, &subscriber)
        subclass_2 = Class.new(@shrine)
        subclass_2.subscribe(:my_event, &subscriber)

        subclass_1.instrument(:my_event, foo: "bar") {}
        subclass_2.instrument(:my_event, foo: "bar") {}

        assert_equal [subclass_1, subclass_2], called
      end

      it "handles nil subscriber" do
        @shrine.subscribe(:my_event)
      end
    end
  end

  describe "events" do
    before do
      @shrine.plugin :instrumentation,
        log_events: Shrine::Plugins::Instrumentation::EVENTS
    end

    describe "Shrine#upload" do
      it "instruments & logs upload event" do
        @notifications.subscribe("upload.shrine") { |event| @event = event }
        @uploader = @shrine.new(:store)

        io            = fakeio
        uploaded_file = assert_logged /^Upload \(\d+ms\) – \{.+\}$/ do
          @shrine.upload(
            io,
            :store,
            upload_options: { foo: "bar" },
            bar: "baz",
          )
        end

        refute_nil @event
        assert_equal :store,           @event[:storage]
        assert_equal uploaded_file.id, @event[:location]
        assert_equal io,               @event[:io]
        assert_equal Hash[foo: "bar"], @event[:upload_options]
        assert_equal @shrine,          @event[:uploader]
        assert_kind_of Integer,        @event[:time]

        assert_equal %i[bar location metadata process upload_options], @event[:options].keys.sort
      end

      it "still forwards options for uploading" do
        file = @shrine.upload(fakeio, :store, location: "foo")

        assert_equal "foo", file.id
      end
    end

    describe "Shrine#get_metadata" do
      it "instruments & logs metadata event" do
        @notifications.subscribe("metadata.shrine") { |event| @event = event }

        io = fakeio
        assert_logged /^Metadata \(\d+ms\) – \{.+\}/ do
          @shrine.upload(
            io,
            :store,
            upload_options: { foo: "bar" },
            bar: "baz",
          )
        end

        refute_nil @event
        assert_equal :store,    @event[:storage]
        assert_equal io,        @event[:io]
        assert_equal @shrine,   @event[:uploader]
        assert_kind_of Integer, @event[:time]

        assert_equal %i[upload_options bar process metadata], @event[:options].keys
      end

      it "skips instrumenting if metadata extraction is skipped" do
        @notifications.subscribe("metadata.shrine") { |event| @event = event }

        refute_logged /^Metadata \(\d+ms\) – \{.+\}/ do
          @shrine.upload(fakeio, :store, metadata: false)
        end

        refute_logged /^Metadata \(\d+ms\) – \{.+\}/ do
          file = @shrine.upload(fakeio, :store, metadata: false)
          @shrine.upload(file, :store)
        end

        assert_nil @event

        assert_logged /^Metadata \(\d+ms\) – \{.+\}/ do
          file = @shrine.upload(fakeio, :store, metadata: false)
          @shrine.upload(file, :store, metadata: true)
        end
      end

      it "still forwards options for metadata extraction" do
        file = @shrine.upload(fakeio, :store, metadata: { "foo" => "bar" })

        assert_equal "bar", file.metadata["foo"]
      end
    end

    describe "UploadedFile#download" do
      it "instruments & logs download event" do
        @notifications.subscribe("download.shrine") { |event| @event = event }

        file = @shrine.upload(fakeio, :store)

        assert_logged /^Download \(\d+ms\) – \{.+\}$/ do
          file.download(foo: "bar")
        end

        refute_nil @event
        assert_equal :store,           @event[:storage]
        assert_equal file.id,          @event[:location]
        assert_equal Hash[foo: "bar"], @event[:download_options]
        assert_equal @shrine,          @event[:uploader]
        assert_kind_of Integer,        @event[:time]
      end

      it "still forwards options for downloading" do
        file = @shrine.upload(fakeio, :store)

        file.storage.expects(:open).with(file.id, foo: "bar").returns(StringIO.new)
        file.download(foo: "bar")
      end
    end

    describe "UploadedFile#stream" do
      it "instruments & logs download event" do
        @notifications.subscribe("download.shrine") { |event| @event = event }

        uploaded_file = @shrine.upload(fakeio, :store)

        assert_logged /^Download \(\d+ms\) – \{.+\}$/ do
          uploaded_file.stream(File::NULL, foo: "bar")
        end

        refute_nil @event
        assert_equal :store,           @event[:storage]
        assert_equal uploaded_file.id, @event[:location]
        assert_equal Hash[foo: "bar"], @event[:download_options]
        assert_equal @shrine,          @event[:uploader]
        assert_kind_of Integer,        @event[:time]
      end

      it "skips instrumenting open event" do
        @notifications.subscribe("open.shrine") { |event| @event = event }

        uploaded_file = @shrine.upload(fakeio, :store)

        refute_logged /^Open \(\d+ms\) – \{.+\}$/ do
          uploaded_file.stream(File::NULL)
        end

        assert_nil @event
      end

      it "doesn't instrument when file already opened" do
        @notifications.subscribe("download.shrine") { |event| @event = event }

        uploaded_file = @shrine.upload(fakeio, :store)
        uploaded_file.open

        refute_logged /^Download \(\d+ms\) – \{.+\}$/ do
          uploaded_file.stream(File::NULL)
        end

        assert_nil @event
      end

      it "still forwards options for downloading" do
        file = @shrine.upload(fakeio, :store)

        file.storage.expects(:open).with(file.id, foo: "bar").returns(StringIO.new)
        file.stream(File::NULL, foo: "bar")
      end
    end

    describe "UploadedFile#open" do
      it "instruments & logs open event without block" do
        @notifications.subscribe("open.shrine") { |event| @event = event }

        uploaded_file = @shrine.upload(fakeio, :store)

        assert_logged /^Open \(\d+ms\) – \{.+\}$/ do
          uploaded_file.open(foo: "bar")
        end

        refute_nil @event
        assert_equal :store,           @event[:storage]
        assert_equal uploaded_file.id, @event[:location]
        assert_equal Hash[foo: "bar"], @event[:download_options]
        assert_equal @shrine,          @event[:uploader]
        assert_kind_of Integer,        @event[:time]
      end

      it "instruments & logs open event with block" do
        @notifications.subscribe("open.shrine") { |event| @event = event }

        uploaded_file = @shrine.upload(fakeio, :store)

        assert_logged /^Open \(\d+ms\) – \{.+\}$/ do
          uploaded_file.open(foo: "bar") {}
        end

        refute_nil @event
        assert_equal :store,           @event[:storage]
        assert_equal uploaded_file.id, @event[:location]
        assert_equal Hash[foo: "bar"], @event[:download_options]
        assert_equal @shrine,          @event[:uploader]
        assert_kind_of Integer,        @event[:time]
      end

      it "still forwards options for downloading" do
        file = @shrine.upload(fakeio, :store)

        file.storage.expects(:open).with(file.id, foo: "bar").returns(StringIO.new)
        file.open(foo: "bar")
      end
    end

    describe "UploadedFile#exists?" do
      it "instruments & logs exists event" do
        @notifications.subscribe("exists.shrine") { |event| @event = event }

        uploaded_file = @shrine.upload(fakeio, :store)

        assert_logged /^Exists \(\d+ms\) – \{.+\}$/ do
          uploaded_file.exists?
        end

        refute_nil @event
        assert_equal :store,           @event[:storage]
        assert_equal uploaded_file.id, @event[:location]
        assert_equal @shrine,          @event[:uploader]
        assert_kind_of Integer,        @event[:time]
      end
    end

    describe "UploadedFile#delete" do
      it "instruments & logs delete events" do
        @notifications.subscribe("delete.shrine") { |event| @event = event }

        uploaded_file = @shrine.upload(fakeio, :store)

        assert_logged /^Delete \(\d+ms\) – \{.+\}$/ do
          uploaded_file.delete
        end

        refute_nil @event
        assert_equal :store,           @event[:storage]
        assert_equal uploaded_file.id, @event[:location]
        assert_equal @shrine,          @event[:uploader]
        assert_kind_of Integer,        @event[:time]
      end
    end
  end

  it "allows selecting events to log" do
    @shrine.plugin :instrumentation, log_events: [:upload]

    refute_logged /^Metadata/ do
      @shrine.upload(fakeio, :store)
    end
  end

  it "allows substituting the log subscriber" do
    @shrine.plugin :instrumentation,
      log_events: [:upload],
      log_subscriber: -> (event) { @event = event }

    refute_logged /^Upload/ do
      @shrine.upload(fakeio, :store)
    end

    refute_nil @event
    assert_equal :upload, @event.name
  end

  it "allows disabling the log subscriber" do
    @shrine.plugin :instrumentation,
      log_events: [:upload],
      log_subscriber: nil

    refute_logged /^Upload/ do
      @shrine.upload(fakeio, :store)
    end
  end
end
