# frozen_string_literal: true

Shrine.deprecation("The logging plugin has been deprecated in favor of instrumentation plugin. The logging plugin will be removed in Shrine 3.")

require "logger"
require "json"
require "time"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/logging.md] on GitHub.
    #
    # [doc/plugins/logging.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/logging.md
    module Logging
      def self.load_dependencies(uploader, *)
        uploader.plugin :hooks
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:logging_stream] = opts.fetch(:stream, uploader.opts.fetch(:logging_stream, $stdout))
        uploader.opts[:logging_logger] = opts.fetch(:logger, uploader.opts.fetch(:logging_logger, uploader.create_logger))
        uploader.opts[:logging_format] = opts.fetch(:format, uploader.opts.fetch(:logging_format, :human))

        Shrine.deprecation("The :heroku logging format has been renamed to :logfmt. Using :heroku name will stop being supported in Shrine 3.") if uploader.opts[:logging_format] == :heroku
      end

      module ClassMethods
        def logger=(logger)
          @logger = logger
        end

        def logger
          @logger ||= opts[:logging_logger]
        end

        def create_logger
          logger = Logger.new(opts[:logging_stream])
          logger.level = Logger::INFO
          logger.level = Logger::WARN if ENV["RACK_ENV"] == "test"
          logger.formatter = pretty_formatter
          logger
        end

        # It makes logging preamble simpler than the default logger. Also, it
        # doesn't output timestamps if on Heroku.
        def pretty_formatter
          proc do |severity, time, program_name, message|
            output = "#{Process.pid}: #{message}\n".dup
            output.prepend "#{time.utc.iso8601(3)} " unless ENV["DYNO"]
            output
          end
        end
      end

      module InstanceMethods
        def store(io, context = {})
          log("store", io, context) { super }
        end

        def delete(io, context = {})
          log("delete", io, context) { super }
        end

        private

        def processed(io, context = {})
          log("process", io, context) { super }
        end

        # Collects the data and sends it for logging.
        def log(action, input, context)
          result, duration = benchmark { yield }

          _log(
            action:       action,
            phase:        context[:action],
            uploader:     self.class.to_s,
            attachment:   context[:name],
            record_class: (context[:record].class.to_s if context[:record]),
            record_id:    (context[:record].id if context[:record].respond_to?(:id)),
            files:        (action == "process" ? [count(input), count(result)] : count(result)),
            duration:     ("%.2f" % duration).to_f,
          ) unless result.nil?

          result
        end

        # Determines format of logging and calls appropriate method.
        def _log(data)
          message = send("_log_message_#{opts[:logging_format]}", data)
          self.class.logger.info(message)
        end

        def _log_message_human(data)
          components = []
          components << "#{data[:action].upcase}"
          components[-1] += "[#{data[:phase]}]" if data[:phase]
          components << "#{data[:uploader]}"
          components[-1] += "[:#{data[:attachment]}]" if data[:attachment]
          components << "#{data[:record_class]}" if data[:record_class]
          components[-1] += "[#{data[:record_id]}]" if data[:record_id]
          components << "#{Array(data[:files]).join("-")} #{"file#{"s" if Array(data[:files]).any?{|n| n > 1}}"}"
          components << "(#{data[:duration]}s)"
          components.join(" ")
        end

        def _log_message_json(data)
          data[:files] = Array(data[:files]).join("-")
          JSON.generate(data)
        end

        def _log_message_logfmt(data)
          data[:files] = Array(data[:files]).join("-")
          data.map { |key, value| "#{key}=#{value}" }.join(" ")
        end
        alias _log_message_heroku _log_message_logfmt # deprecated alias

        # We may have one file, a hash of versions, or an array of files or
        # hashes.
        def count(object)
          case object
          when Hash
            object.count
          when Array
            object.inject(0) { |sum, o| sum += count(o) }
          else
            1
          end
        end

        def benchmark
          start = Time.now
          result = yield
          finish = Time.now
          [result, finish - start]
        end
      end
    end

    register_plugin(:logging, Logging)
  end
end
