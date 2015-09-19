class Shrine
  module Plugins
    module StoreDimensions
      def self.load_dependencies(uploader, extractor:)
        case extractor
        when :mini_magick then require "mini_magick"
        when :rmagick     then require "rmagick"
        when :dimensions  then require "dimensions"
        end
      end

      def self.configure(uploader, extractor:)
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

        def _extract_dimensions_with_mini_magick(io)
          image = MiniMagick::Image.new(io.path)
          [image.width, image.height]
        end

        def _extract_dimensions_with_rmagick(io)
          image = Magick::Image.ping(io.path).first
          [image.columns, image.rows]
        end

        def _extract_dimensions_with_dimensions(io)
          if io.respond_to?(:path)
            Dimensions.dimensions(io.path)
          else
            Dimensions(io).dimensions
          end
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
