require "logger"
require "benchmark"
require "json"

class Shrine
  module Plugins
    module Logging
      def self.configure(uploader, logger: nil, stream: $stdout, format: :human)
        uploader.logger = logger if logger
        uploader.opts[:logging_stream] = stream
        uploader.opts[:logging_format] = format
      end

      FORMATTER = proc do |severity, time, program_name, message|
        output = "##{Process.pid}: #{message}\n"
        output.prepend "#{time.utc.iso8601(3)} " unless ENV["DYNO"]
        output
      end

      module ClassMethods
        def logger=(logger)
          @logger = logger || Logger.new(nil)
        end

        def logger
          @logger ||= (
            logger = Logger.new(opts[:logging_stream])
            logger.level = Logger::INFO
            logger.formatter = FORMATTER
            logger
          )
        end
      end

      module InstanceMethods
        def store(io, context = {})
          log("store", context) { super }
        end

        def delete(uploaded_file, context = {})
          log("delete", context) { super }
        end

        private

        def processed(io, context = {})
          log("process", context) { super }
        end

        def log(action, context)
          result, duration = benchmark { yield }

          _log(
            action:       action,
            phase:        context[:phase],
            uploader:     self.class,
            attachment:   context[:name],
            record_class: (context[:record].class if context[:record]),
            record_id:    (context[:record].id if context[:record]),
            files:        count(result),
            duration:     ("%.2f" % duration).to_f,
          ) unless result.nil?

          result
        end

        def _log(data)
          message = send("_log_message_#{opts[:logging_format]}", data)
          self.class.logger.info(message)
        end

        def _log_message_human(data)
          components = []
          components << "#{data[:action].upcase}"
          components.last << "[#{data[:phase]}]" if data[:phase]
          components << "#{data[:uploader]}"
          components.last << "[:#{data[:attachment]}]" if data[:attachment]
          components << "#{data[:record_class]}[#{data[:record_id]}]" if data[:record_class]
          components << (data[:files] > 1 ? "#{data[:files]} files" : "#{data[:files]} file")
          components << "(#{data[:duration]}s)"
          components.join(" ")
        end

        def _log_message_json(data)
          data.to_json
        end

        def _log_message_heroku(data)
          data.map { |key, value| "#{key}=#{value}" }.join(" ")
        end

        def count(object)
          case object
          when Hash  then object.count
          when Array then object.inject(0) { |sum, o| sum += count(o) }
          else            1
          end
        end

        def benchmark
          result = nil
          duration = Benchmark.realtime { result = yield }
          [result, duration]
        end
      end
    end

    register_plugin(:logging, Logging)
  end
end
