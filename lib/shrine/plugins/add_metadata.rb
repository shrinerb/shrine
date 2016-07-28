class Shrine
  module Plugins
    # The metadata plugin provides a convenient method for extracting and
    # adding custom metadata values.
    #
    #     plugin :add_metadata
    #
    #     add_metadata "exif" do |io, context|
    #       MiniMagick::Image.new(io.path).exif
    #     end
    #
    # If the result of the block is nil, the metadata value won't be assigned.
    #
    # This plugin can also be used to override existing metadata values.
    module AddMetadata
      def self.configure(uploader)
        uploader.opts[:metadata] = {}
      end

      module ClassMethods
        def add_metadata(name, &block)
          opts[:metadata][name] = block
        end
      end

      module InstanceMethods
        def extract_metadata(io, context)
          metadata = super

          opts[:metadata].each do |name, block|
            value = instance_exec(io, context, &block)
            metadata[name] = value unless value.nil?
          end

          metadata
        end
      end
    end

    register_plugin(:add_metadata, AddMetadata)
  end
end
