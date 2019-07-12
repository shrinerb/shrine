require "test_helper"
require "shrine/plugins/instrumentation"
require "active_support/notifications"
require "dry-monitor"

describe Shrine::Plugins::Instrumentation do
  before do
    @notifications = Dry::Monitor::Notifications.new(:test)
    @uploader = uploader
    @shrine = @uploader.class
    @shrine.plugin :instrumentation, notifications: @notifications
  end

  describe "Shrine.instrument" do
    before do
      @uploader = uploader { plugin :instrumentation }
      @shrine = @uploader.class
    end

    after do
      # clear all subscribers
      ActiveSupport::Notifications.notifier = ActiveSupport::Notifications::Fanout.new
    end

    it "sends notification to default notifications" do
      ActiveSupport::Notifications.subscribe("my_event.shrine") do |*args|
        @event = ActiveSupport::Notifications::Event.new(*args)
      end

      @shrine.instrument("my_event", foo: "bar") {}

      assert_instance_of ActiveSupport::Notifications::Event, @event
      assert_equal "bar", @event.payload[:foo]
      assert_instance_of Float, @event.duration
    end

    it "sends notification to ActiveSupport::Notifications" do
      @shrine.plugin :instrumentation, notifications: ActiveSupport::Notifications

      ActiveSupport::Notifications.subscribe("my_event.shrine") do |*args|
        @event = ActiveSupport::Notifications::Event.new(*args)
      end

      @shrine.instrument("my_event", foo: "bar") {}

      assert_instance_of ActiveSupport::Notifications::Event, @event
      assert_equal "bar", @event.payload[:foo]
      assert_instance_of Float, @event.duration
    end

    it "sends notification to Dry::Monitor::Notifications" do
      notifications = Dry::Monitor::Notifications.new(:test)
      notifications.register_event("my_event.shrine")

      @shrine.plugin :instrumentation, notifications: notifications

      notifications.subscribe("my_event.shrine") { |event| @event = event }
      @shrine.instrument("my_event", foo: "bar") {}

      assert_instance_of Dry::Events::Event, @event
      assert_equal "bar", @event[:foo]
      assert_instance_of Integer, @event[:time]
    end
  end

  describe "storage_upload" do
    it "sends upload event" do
      @notifications.subscribe("storage_upload.shrine") { |event| @event = event }

      uploaded_file = @shrine.upload(
        io = fakeio,
        :store,
        upload_options: { foo: "bar" },
        bar: "baz",
      )

      refute_nil @event
      assert_equal :store,                                   @event[:storage]
      assert_equal uploaded_file.id,                         @event[:location]
      assert_equal io,                                       @event[:io]
      assert_equal Hash[foo: "bar"],                         @event[:upload_options]
      assert_equal %i[upload_options bar location metadata], @event[:options].keys
      assert_equal @shrine,                                  @event[:uploader]
      assert_instance_of Integer,                            @event[:time]
    end

    it "logs upload event" do
      @notifications.subscribe("storage_upload.shrine") { |event| @event = event }

      assert_logged /^Upload \(\d+ms\) – \{.+\}$/ do
        uploaded_file = @shrine.upload(
          io = fakeio,
          :store,
          upload_options: { foo: "bar" },
          bar: "baz",
        )
      end
    end
  end

  describe "metadata" do
    it "sends metadata event" do
      # assertions
    end
  end
end
