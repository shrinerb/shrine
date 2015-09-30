class Shrine
  module Plugins
    module StoreDimensions
      def self.load_dependencies(uploader, extractor: :fastimage)
        case extractor
        when :fastimage then require "fastimage"
        end
      end

      def self.configure(uploader, extractor: :fastimage)
        uploader.opts[:dimensions_extractor] = extractor
      end

      module InstanceMethods
        def extract_metadata(io, context)
          width, height = extract_dimensions(io)

          metadata = super
          metadata["width"] = width
          metadata["height"] = height
          metadata
        end

        def extract_dimensions(io)
          extractor = opts[:dimensions_extractor]

          if io.respond_to?(:width) && io.respond_to?(:height)
            [io.width, io.height]
          elsif extractor.is_a?(Symbol)
            send(:"_extract_dimensions_with_#{extractor}", io)
          else
            extractor.call(io)
          end
        end

        private

        def _extract_dimensions_with_fastimage(io)
          FastImage.size(io)
        end
      end

      module FileMethods
        def width
          metadata.fetch("width")
        end

        def height
          metadata.fetch("height")
        end
      end
    end

    register_plugin(:store_dimensions, StoreDimensions)
  end
end
