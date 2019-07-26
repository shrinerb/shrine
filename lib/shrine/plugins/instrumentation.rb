# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/instrumentation.md] on GitHub.
    #
    # [doc/plugins/instrumentation.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/instrumentation.md
    module Instrumentation
      EVENTS = %i[upload download exists delete metadata].freeze

      # We use a proc in order to be able identify listeners.
      LOG_SUBSCRIBER = -> (event) { LogSubscriber.call(event) }

      def self.configure(uploader, **opts)
        uploader.opts[:instrumentation] ||= { log_subscriber: LOG_SUBSCRIBER, log_events: EVENTS }
        uploader.opts[:instrumentation].merge!(opts)
        uploader.opts[:instrumentation][:notifications] ||= ::ActiveSupport::Notifications

        # we assign it to the top-level so that it's duplicated on subclassing
        uploader.opts[:instrumentation_subscribers] ||= Hash.new { |h, k| h[k] = [] }

        uploader.opts[:instrumentation][:log_events].each do |event_name|
          uploader.subscribe(event_name, &uploader.opts[:instrumentation][:log_subscriber])
        end
      end

      module ClassMethods
        # Sends a `*.shrine` event.
        #
        #     # sends a `my_event.shrine` event
        #     Shrine.instrument(:my_event) do
        #       # work
        #     end
        def instrument(event_name, payload = {}, &block)
          payload[:uploader] = self

          notifications.instrument("#{event_name}.shrine", payload, &block)
        end

        # Subscribes to a `*.shrine` event. It rejects duplicate subscribers.
        #
        #     # subscribes to the `storage_upload.shrine` event
        #     Shrine.subscribe(:storage_upload) do |event|
        #       event.name #=> :storage_upload
        #       event.payload #=> { location: "...", ... }
        #       event[:location] #=> "..."
        #       event.duration #=> 50 (in milliseconds)
        #     end
        def subscribe(event_name, &subscriber)
          return if subscriber.nil?
          return if subscribers[event_name].include?(subscriber)

          notifications.subscribe("#{event_name}.shrine") do |event|
            subscriber.call(event) if event[:uploader] <= self
          end

          subscribers[event_name] << subscriber
        end

        private

        def notifications
          Notifications.new(opts[:instrumentation][:notifications])
        end

        def log_subscriber
          opts[:instrumentation][:log_subscriber]
        end

        def subscribers
          opts[:instrumentation_subscribers]
        end
      end

      module InstanceMethods
        private

        # Sends a `upload.shrine` event.
        def _upload(io, **options)
          self.class.instrument(
            :upload,
            storage: storage_key,
            location: options[:location],
            io: io,
            upload_options: options[:upload_options] || {},
            options: options,
          ) { super }
        end

        # Sends a `metadata.shrine` event.
        def get_metadata(io, metadata: nil, **options)
          return super if io.is_a?(UploadedFile) && metadata != true || metadata == false

          self.class.instrument(
            :metadata,
            storage: storage_key,
            io: io,
            options: options.merge(metadata: metadata),
          ) { super }
        end
      end

      module FileMethods
        # Sends a `download.shrine` event.
        def open(**options)
          shrine_class.instrument(
            :download,
            storage: storage_key,
            location: id,
            download_options: options,
          ) { super }
        end

        # Sends a `exists.shrine` event.
        def exists?
          shrine_class.instrument(
            :exists,
            storage: storage_key,
            location: id,
          ) { super }
        end

        # Sends a `delete.shrine` event.
        def delete
          shrine_class.instrument(
            :delete,
            storage: storage_key,
            location: id,
          ) { super }
        end
      end

      # Abstracts away different types of notifications objects
      # (`ActiveSupport::Notifications` and `Dry::Monitor::Notifications`).
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

      # Abstracts away different kind of event objects
      # (`ActiveSupport::Notifications::Event` and `Dry::Events::Event`).
      class Event
        attr_reader :event

        def initialize(event)
          @event = event
        end

        def name
          library_send(:name).chomp(".shrine").to_sym
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

      # Logs received events.
      class LogSubscriber
        # Entry point for logging.
        def self.call(event)
          new.public_send(:"on_#{event.name}", event)
        end

        def on_upload(event)
          log "Upload (#{event.duration}ms) – #{format(
            storage:        event[:storage],
            location:       event[:location],
            io:             event[:io].class,
            upload_options: event[:upload_options],
            uploader:       event[:uploader],
          )}"
        end

        def on_download(event)
          log "Download (#{event.duration}ms) – #{format(
            storage:          event[:storage],
            location:         event[:location],
            download_options: event[:download_options],
            uploader:         event[:uploader],
          )}"
        end

        def on_exists(event)
          log "Exists (#{event.duration}ms) – #{format(
            storage:  event[:storage],
            location: event[:location],
            uploader: event[:uploader],
          )}"
        end

        def on_delete(event)
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

    register_plugin(:instrumentation, Instrumentation)
  end
end
