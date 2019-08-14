# frozen_string_literal: true

Shrine.deprecation("The processing plugin is deprecated and will be removed in Shrine 4. If you were using it with versions plugin, use the new derivatives plugin instead.")

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/processing.md] on GitHub.
    #
    # [doc/plugins/processing.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/processing.md
    module Processing
      def self.configure(uploader)
        uploader.opts[:processing] ||= {}
      end

      module ClassMethods
        def process(action, &block)
          opts[:processing][action] ||= []
          opts[:processing][action] << block
        end
      end

      module InstanceMethods
        def upload(io, process: true, **options)
          if process
            input = process(io, **options)
          else
            input = io
          end

          super(input, **options)
        end

        private

        def process(io, **options)
          pipeline = processing_pipeline(options[:action])
          pipeline.inject(io) do |input, processor|
            instance_exec(input, options, &processor) || input
          end
        end

        def processing_pipeline(key)
          opts[:processing][key] || []
        end
      end
    end

    register_plugin(:processing, Processing)
  end
end
