class Uploadie
  module Plugins
    # plugin :processing, storage: :cache, processor: -> (raw_image, context) do
    #   size_700 = resize_to_fit(raw_image, 700, 700)
    #   size_500 = resize_to_fit(raw_image, 500, 500)
    #   size_300 = resize_to_fit(raw_image, 300, 300)
    #
    #   {large: size_700, medium: size_500, small: size_300}
    # end
    #
    module Processing
      def self.load_dependencies(uploadie, *)
        uploadie.plugin :versions
      end

      def self.configure(uploadie, processor:, storage:)
        raise ArgumentError, ":processor must be a proc or a symbol" if !processor.is_a?(Proc) && !processor.is_a?(Symbol)
        uploadie.opts[:processor] = processor

        uploadie.storages.fetch(storage)
        uploadie.opts[:processing_storage] = storage
      end

      module InstanceMethods
        private

        def store(io, **context)
          if processing?(io, context)
            processor = self.class.opts[:processor]
            processor = method(processor) if processor.is_a?(Symbol)
            io = io.download if io.is_a?(Uploadie::UploadedFile)

            result = instance_exec(io, context, &processor)

            super(result, context)
          else
            super
          end
        end

        def processing?(io, context)
          io?(io) && storage_key == self.class.opts[:processing_storage]
        end
      end
    end

    register_plugin(:processing, Processing)
  end
end
