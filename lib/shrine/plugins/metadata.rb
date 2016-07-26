class Shrine
  module Plugins
    # The metadata plugin provides a convenient method for extracting and
    # adding custom metadata values.
    #
    #     plugin :metadata
    #
    #     metadata "exif" do |io, context|
    #       MiniMagick::Image.new(io.path).exif
    #     end
    #
    # This can also be used to override existing metadata values.
    module Metadata
      def self.configure(uploader)
        uploader.opts[:metadata] = {}
      end

      module ClassMethods
        def metadata(name, &block)
          opts[:metadata][name] = block
        end
      end

      module InstanceMethods
        def extract_metadata(io, context)
          metadata = super

          opts[:metadata].each do |name, block|
            metadata[name] = instance_exec(io, context, &block)
          end

          metadata
        end
      end
    end

    register_plugin(:metadata, Metadata)
  end
end
