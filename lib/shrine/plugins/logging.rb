require "logger"
require "benchmark"
require "json"

class Shrine
  module Plugins
    # The logging plugin logs any storing/processing/deleting that is performed.
    #
    #     plugin :logging
    #
    # This plugin is useful when you want to have overview of what exactly is
    # going on, or you simply want to have it logged for future debugging.
    # By default the logging output looks something like this:
    #
    #     2015-10-09T20:06:06.676Z #25602: UPLOAD[direct] ImageUploader[:avatar] User[29543] 1 file (0.1s)
    #     2015-10-09T20:06:06.854Z #25602: PROCESS[promote]: ImageUploader[:avatar] User[29543] 3 files (0.22s)
    #     2015-10-09T20:06:07.133Z #25602: DELETE[destroy]: ImageUploader[:avatar] User[29543] 3 files (0.07s)
    #
    # The plugin accepts the following options:
    #
    # :format
    # :  This allows you to change the logging output into something that may be
    #    easier to grep. Accepts `:human` (default), `:json` and `:heroku`.
    #
    # :stream
    # :  The default logging stream is `$stdout`, but you may want to change it,
    #    e.g. if you log into a file. This option is passed directly to
    #    `Logger.new` (from the "logger" Ruby standard library).
    #
    # :logger
    # :  This allows you to change the logger entirely. This is useful for example
    #    in Rails applications, where you might want to assign this option to
    #    `Rails.logger`.
    #
    # The default format is probably easiest to read, but may not be easiest to
    # grep. If this is important to you, you can switch to another format:
    #
    #     plugin :logging, format: :json
    #     # {"action":"upload","phase":"direct","uploader":"ImageUploader","attachment":"avatar",...}
    #
    #     plugin :logging, format: :heroku
    #     # action=upload phase=direct uploader=ImageUploader attachment=avatar record_class=User ...
    #
    # Logging is by default disabled in tests, but you can enable it by setting
    # `Shrine.logger.level = Logger::INFO`.
    module Logging
      def self.configure(uploader, logger: nil, stream: $stdout, format: :human)
        uploader.logger = logger if logger
        uploader.opts[:logging_stream] = stream
        uploader.opts[:logging_format] = format
      end

      module ClassMethods
        def logger=(logger)
          @logger = logger || Logger.new(nil)
        end

        # Initializes a new logger if it hasn't been initialized.
        def logger
          @logger ||= (
            logger = Logger.new(opts[:logging_stream])
            logger.level = Logger::INFO
            logger.level = Logger::WARN if ENV["RACK_ENV"] == "test"
            logger.formatter = pretty_formatter
            logger
          )
        end

        # It makes logging preamble simpler than the default logger. Also, it
        # doesn't output timestamps if on Heroku.
        def pretty_formatter
          proc do |severity, time, program_name, message|
            output = "#{Process.pid}: #{message}\n"
            output.prepend "#{time.utc.iso8601(3)} " unless ENV["DYNO"]
            output
          end
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

        # Collects the data and sends it for logging.
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

        # We may have one file, a hash of versions, or an array of files or
        # hashes.
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
