# frozen_string_literal: true

class Shrine
  module Plugins
    # Shrine uploaders can define the `#process` method, which will get called
    # whenever a file is uploaded. It is given the original file, and is
    # expected to return the processed files.
    #
    #     def process(io, context)
    #       # you can process the original file `io` and return processed file(s)
    #     end
    #
    # However, when handling files as attachments, the same file is uploaded
    # to temporary and permanent storage. Since we only want to apply the same
    # processing once, we need to branch based on the context.
    #
    #     def process(io, context)
    #       if context[:action] == :store # promote phase
    #         # ...
    #       end
    #     end
    #
    # The `processing` plugin simplifies this by allowing us to declaratively
    # define file processing for specified actions.
    #
    #     plugin :processing
    #
    #     process(:store) do |io, context|
    #       # ...
    #     end
    #
    # An example of resizing an image using the [image_processing] library:
    #
    #     include ImageProcessing::MiniMagick
    #
    #     process(:store) do |io, context|
    #       resize_to_limit!(io.download, 800, 800)
    #     end
    #
    # The declarations are additive and inheritable, so for the same action you
    # can declare multiple blocks, and they will be performed in the same order,
    # with output from previous block being the input to next.
    #
    # You can manually trigger the defined processing via the uploader, you
    # just need to specify `:action` to the name of your processing block:
    #
    #     uploader.upload(file, action: :store)  # process and upload
    #     uploader.process(file, action: :store) # only process
    #
    # If you want the result of processing to be multiple files, use the
    # `versions` plugin.
    #
    # [image_processing]: https://github.com/janko-m/image_processing
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
