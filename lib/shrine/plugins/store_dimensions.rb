class Shrine
  module Plugins
    module StoreDimensions
      def self.load_dependencies(uploader, analyzer: :fastimage)
        case analyzer
        when :fastimage then require "fastimage"
        end
      end

      def self.configure(uploader, analyzer: :fastimage)
        uploader.opts[:dimensions_analyzer] = analyzer
      end

      module InstanceMethods
        def extract_metadata(io, context)
          width, height = extract_dimensions(io)

          super.update(
            "width"  => width,
            "height" => height,
          )
        end

        def extract_dimensions(io)
          analyzer = opts[:dimensions_analyzer]

          if io.respond_to?(:width) && io.respond_to?(:height)
            [io.width, io.height]
          elsif analyzer.is_a?(Symbol)
            send(:"_extract_dimensions_with_#{analyzer}", io)
          else
            analyzer.call(io)
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
