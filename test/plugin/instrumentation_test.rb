require "test_helper"
require "shrine/plugins/instrumentation"
require "active_support/notifications"
require "dry-monitor"

describe Shrine::Plugins::Instrumentation do
  before do
    @notifications = Dry::Monitor::Notifications.new(:test)
    @uploader = uploader
    @shrine = @uploader.class
    @shrine.plugin :instrumentation, notifications: @notifications, log_events: []
  end

  after do
    # clear all subscribers
    ActiveSupport::Notifications.notifier = ActiveSupport::Notifications::Fanout.new
  end

  describe "Shrine.instrument" do
    before do
      @uploader = uploader { plugin :instrumentation }
      @shrine = @uploader.class
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
      assert_equal "bar", @event[:foo]
      assert_instance_of Integer, @event[:time]
    end
  end

  describe "Shrine.subscribe" do
    it "yields events for dry-monitor" do
      @shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)
      @shrine.subscribe(:my_event) { |event| @event = event }
      @shrine.instrument(:my_event, foo: "bar") {}

      refute_nil @event
      assert_equal :my_event,             @event.name
      assert_equal "bar",                 @event[:foo]
      assert_equal %i[foo time uploader], @event.payload.keys.sort
      assert_instance_of Integer,         @event.duration
    end

    it "yields events for ActiveSupport::Notifications" do
      @shrine.plugin :instrumentation, notifications: ActiveSupport::Notifications
      @shrine.subscribe(:my_event) { |event| @event = event }
      @shrine.instrument(:my_event, foo: "bar") {}

      refute_nil @event
      assert_equal :my_event,        @event.name
      assert_equal "bar",            @event[:foo]
      assert_equal %i[foo uploader], @event.payload.keys.sort
      assert_instance_of Integer,    @event.duration
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

  describe "events" do
    before do
      @shrine.plugin :instrumentation, log_events: %i[
        upload
        download
        exists
        delete
        metadata
      ]
    end

    it "instruments & logs upload events" do
      @notifications.subscribe("upload.shrine") { |event| @event = event }

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
      assert_equal :store,                                   @event[:storage]
      assert_equal uploaded_file.id,                         @event[:location]
      assert_equal io,                                       @event[:io]
      assert_equal Hash[foo: "bar"],                         @event[:upload_options]
      assert_equal %i[bar location metadata upload_options], @event[:options].keys.sort
      assert_equal @shrine,                                  @event[:uploader]
      assert_instance_of Integer,                            @event[:time]
    end

    it "instruments & logs metadata events" do
      @notifications.subscribe("metadata.shrine") { |event| @event = event }

      io            = fakeio
      uploaded_file = assert_logged /^Metadata \(\d+ms\) – \{.+\}/ do
        @shrine.upload(
          io,
          :store,
          upload_options: { foo: "bar" },
          bar: "baz",
        )
      end

      refute_nil @event
      assert_equal :store,                 @event[:storage]
      assert_equal io,                     @event[:io]
      assert_equal %i[upload_options bar], @event[:options].keys
      assert_equal @shrine,                @event[:uploader]
      assert_instance_of Integer,          @event[:time]
    end

    it "instruments & logs download events" do
      @notifications.subscribe("download.shrine") { |event| @event = event }

      uploaded_file = @shrine.upload(fakeio, :store)
      @shrine.storages[:store].instance_eval { def open(id, **options); super(id); end }

      assert_logged /^Download \(\d+ms\) – \{.+\}$/ do
        uploaded_file.open(foo: "bar", &:read)
      end

      refute_nil @event
      assert_equal :store,           @event[:storage]
      assert_equal uploaded_file.id, @event[:location]
      assert_equal Hash[foo: "bar"], @event[:download_options]
      assert_equal @shrine,          @event[:uploader]
      assert_instance_of Integer,    @event[:time]
    end

    it "instruments & logs exists events" do
      @notifications.subscribe("exists.shrine") { |event| @event = event }

      uploaded_file = @shrine.upload(fakeio, :store)

      assert_logged /^Exists \(\d+ms\) – \{.+\}$/ do
        uploaded_file.exists?
      end

      refute_nil @event
      assert_equal :store,           @event[:storage]
      assert_equal uploaded_file.id, @event[:location]
      assert_equal @shrine,          @event[:uploader]
      assert_instance_of Integer,    @event[:time]
    end

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
      assert_instance_of Integer,    @event[:time]
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
