# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/instrumentation.md] on GitHub.
    #
    # [doc/plugins/instrumentation.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/instrumentation.md
    module Instrumentation
      EVENTS = %i[
        storage_upload
        storage_download
        storage_exists
        storage_delete
        metadata
      ].freeze

      def self.configure(uploader, opts = {})
        uploader.opts[:instrumentation] ||= { log_subscriber: LogSubscriber.new }
        uploader.opts[:instrumentation].merge!(opts)
        uploader.opts[:instrumentation][:notifications] ||= ActiveSupport::Notifications

        uploader.send(:attach_log_subscriber)
      end

      module ClassMethods
        def instrument(event_name, payload = {}, &block)
          payload[:uploader] = self

          notifications.instrument("#{event_name}.shrine", payload, &block)
        end

        def subscribe(event_name, &block)
          notifications.subscribe("#{event_name}.shrine", &block)
        end

        private

        def attach_log_subscriber
          EVENTS.each do |event_name|
            subscribe(event_name) { |event| log_subscriber&.call(event) }
          end
        end

        def notifications
          Notifications.new(opts[:instrumentation][:notifications])
        end

        def log_subscriber
          opts[:instrumentation][:log_subscriber]
        end
      end

      module InstanceMethods
        private

        def copy(io, context)
          self.class.instrument(
            :storage_upload,
            storage: storage_key,
            location: context[:location],
            io: io,
            upload_options: context[:upload_options] || {},
            options: context,
          ) { super }
        end

        def get_metadata(io, context)
          return super if io.is_a?(UploadedFile) && context[:metadata] != true || context[:metadata] == false

          self.class.instrument(
            :metadata,
            storage: storage_key,
            io: io,
            options: context,
          ) { super }
        end
      end

      module FileMethods
        def open(**options)
          shrine_class.instrument(
            :storage_download,
            storage: storage_key.to_sym,
            location: id,
            download_options: options,
          ) { super }
        end

        def exists?
          shrine_class.instrument(
            :storage_exists,
            storage: storage_key.to_sym,
            location: id,
          ) { super }
        end

        def delete
          shrine_class.instrument(
            :storage_delete,
            storage: storage_key.to_sym,
            location: id,
          ) { super }
        end
      end

      # Abstracts away different types of notifications objects.
      class Notifications
        attr_reader :notifications

        def initialize(notifications)
          @notifications = notifications
        end

        def subscribe(event_name, &block)
          library_send(:subscribe, event_name) do |event|
            yield Event.new(event)
          end
        end

        def instrument(event_name, payload, &block)
          notifications.instrument(event_name, payload, &block)
        end

        private

        def dry_monitor_subscribe(event_name, &block)
          notifications.register_event(event_name)
          notifications.subscribe(event_name, &block)
        end

        def active_support_subscribe(event_name, &block)
          notifications.subscribe(event_name) do |*args|
            yield ActiveSupport::Notifications::Event.new(*args)
          end
        end

        def library_send(method_name, *args, &block)
          case notifications.to_s
          when /Dry::Monitor::Notifications/
            send(:"dry_monitor_#{method_name}", *args, &block)
          when /ActiveSupport::Notifications/
            send(:"active_support_#{method_name}", *args, &block)
          else
            notifications.send(method_name, *args, &block)
          end
        end
      end

      # Abstracts away different kind of event objects.
      class Event
        attr_reader :event

        def initialize(event)
          @event = event
        end

        def name
          library_send(:name).chomp(".shrine")
        end

        def payload
          event.payload
        end

        def [](name)
          event.payload.fetch(name)
        end

        def duration
          library_send(:duration)
        end

        private

        def dry_events_name
          event.id
        end

        def active_support_name
          event.name
        end

        def dry_events_duration
          event[:time]
        end

        def active_support_duration
          event.duration.to_i
        end

        def library_send(method_name, *args, &block)
          case event.class.name
          when "ActiveSupport::Notifications::Event"
            send(:"active_support_#{method_name}", *args, &block)
          when "Dry::Events::Event"
            send(:"dry_events_#{method_name}", *args, &block)
          else
            event.send(method_name, *args, &block)
          end
        end
      end
    end

    register_plugin(:instrumentation, Instrumentation)
  end

  class LogSubscriber
    # Entry point for logging.
    def call(event)
      public_send(:"on_#{event.name}", event)
    end

    def on_storage_upload(event)
      log "Upload (#{event.duration}ms) – #{format(
        storage:        event[:storage],
        location:       event[:location],
        io:             event[:io].class,
        upload_options: event[:upload_options],
        uploader:       event[:uploader],
      )}"
    end

    def on_storage_download(event)
      log "Download (#{event.duration}ms) – #{format(
        storage:          event[:storage],
        location:         event[:location],
        download_options: event[:download_options],
        uploader:         event[:uploader],
      )}"
    end

    def on_storage_exists(event)
      log "Exists (#{event.duration}ms) – #{format(
        storage:  event[:storage],
        location: event[:location],
        uploader: event[:uploader],
      )}"
    end

    def on_storage_delete(event)
      log "Delete (#{event.duration}ms) – #{format(
        storage:  event[:storage],
        location: event[:location],
        uploader: event[:uploader],
      )}"
    end

    def on_metadata(event)
      log "Metadata (#{event.duration}ms) – #{format(
        storage:  event[:storage],
        io:       event[:io].class,
        uploader: event[:uploader],
      )}"
    end

    private

    def format(properties = {})
      properties.inspect
    end

    def log(message)
      logger.info(message)
    end

    def logger
      Shrine.logger
    end
  end
end
