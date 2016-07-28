class Shrine
  module Plugins
    # The process plugin allows you to declaratively define
    # file processing for specified actions, allowing you to transform
    #
    #     def process(io, context)
    #       if context[:action] == :store
    #         # ...
    #       end
    #     end
    #
    # into
    #
    #     process(:store) do |io, context|
    #       # ...
    #     end
    #
    # The declarations are additive and inherited, so for the same action you
    # can declare multiple blocks, and they will be performed in the same order,
    # where output from previous will be input to next. You can return `nil`
    # in any block to signal that no processing was performed and that the
    # original file should be used.
    module Processing
      def self.configure(uploader)
        uploader.opts[:processing] = {}
      end

      module ClassMethods
        def process(action, &block)
          opts[:processing][action] ||= []
          opts[:processing][action] << block
        end
      end

      module InstanceMethods
        def process(io, context = {})
          pipeline = opts[:processing][context[:action]] || []

          result = pipeline.inject(io) do |input, processing|
            instance_exec(input, context, &processing) || input
          end

          result unless result == io
        end
      end
    end

    register_plugin(:processing, Processing)
  end
end
