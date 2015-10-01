require "logger"
require "benchmark"

class Shrine
  module Plugins
    module Logging
      def self.configure(uploader, logger: nil, stream: $stdout)
        uploader.logger = logger if logger
        uploader.opts[:logging_stream] = stream
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
        def processed(input, context = {})
          output, duration = benchmark { super }
          log("#{files(input)} => #{files(output)}",
              action: "process", duration: duration, context: context) if output
          output
        end

        def delete(uploaded_file, context = {})
          result, duration = benchmark { super }
          log("#{files(result)}",
              action: "delete", duration: duration, context: context)
          result
        end

        private

        def store(io, context = {})
          result, duration = benchmark { super }
          log("#{files(result)}",
              action: "upload", duration: duration, context: context)
          result
        end

        def log(message, action:, duration:, context:)
          components = []
          components << "#{action.upcase}"
          components.last << "[#{context[:phase]}]" if context[:phase]
          components << "#{self.class}"
          components.last << "[:#{context[:name]}]" if context[:name]
          components << message
          components << "(%.2fs)" % duration

          self.class.logger.info components.join(" ")
        end

        def files(object)
          count = count(object)
          count > 1 ? "#{count} files" : "#{count} file"
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
