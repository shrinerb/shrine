class Uploadie
  module Plugins
    module StoreDimensions
      SUPPORTED_LIBRARIES = [:mini_magick, :rmagick, :dimensions]

      def self.configure(uploadie, library:)
        raise Error, "unsupported dimensions library: #{library.inspect}" if !SUPPORTED_LIBRARIES.include?(library)
        uploadie.opts[:dimensions_library] = library
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
          if io.respond_to?(:width) && io.respond_to?(:height)
            [io.width, io.height]
          else
            send(:"_extract_#{opts[:dimensions_library]}_dimensions", io)
          end
        end

        private

        def _extract_mini_magick_dimensions(io)
          image = MiniMagick::Image.new(io.path)
          [image.width, image.height]
        end

        def _extract_rmagick_dimensions(io)
          image = Magick::Image.ping(io.path).first
          [image.columns, image.rows]
        end

        def _extract_dimensions_dimensions(io)
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
