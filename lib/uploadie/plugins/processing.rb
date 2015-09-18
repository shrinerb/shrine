class Uploadie
  module Plugins
    # plugin :versions, storage: :cache, processor: -> (raw_image, context) do
    #   size_700 = resize_to_fit(raw_image, 700, 700)
    #   size_500 = resize_to_fit(raw_image, 500, 500)
    #   size_300 = resize_to_fit(raw_image, 300, 300)
    #
    #   {large: size_700, medium: size_500, small: size_300}
    # end
    #
    module Processing
      def self.load_dependencies(uploader, versions: nil, **)
        uploader.plugin :_versions if versions
      end

      def self.configure(uploader, processor:, storage:, **)
        raise ArgumentError, ":processor must be a proc" if !processor.is_a?(Proc)
        uploader.opts[:processor] = processor

        uploader.storage(storage)
        uploader.opts[:processing_storage] = storage
      end

      module InstanceMethods
        def upload(io, context = {})
          if processing?(io, context)
            processor = opts[:processor]
            io = io.download if io.is_a?(Uploadie::UploadedFile)

            processed = instance_exec(io, context, &processor)

            super(processed, context)
          else
            super
          end
        end

        private

        def processing?(io, context)
          storage_key == self.class.opts[:processing_storage]
        end
      end
    end

    register_plugin(:processing, Processing)
  end
end
