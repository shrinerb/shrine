class Shrine
  module Plugins
    # The `store_dimensions` plugin extracts and stores dimensions of the
    # uploaded image using the [fastimage] gem, which has built-in protection
    # agains [image bombs].
    #
    #     plugin :store_dimensions
    #
    # It adds "width" and "height" metadata values to Shrine::UploadedFile,
    # and creates `#width`, `#height` and `#dimensions` reader methods.
    #
    #     image = uploader.upload(file)
    #
    #     image.metadata["width"]  #=> 300
    #     image.metadata["height"] #=> 500
    #     # or
    #     image.width  #=> 300
    #     image.height #=> 500
    #     # or
    #     image.dimensions #=> [300, 500]
    #
    # You can provide your own custom dimensions analyzer, and reuse any of the
    # built-in analyzers; you just need to return a two-element array of width
    # and height, or nil to signal that dimensions weren't extracted.
    #
    #     require "mini_magick"
    #
    #     plugin :store_dimensions, analyzer: ->(io, analyzers) do
    #       dimensions = analyzers[:fastimage].call(io)
    #       dimensions || MiniMagick::Image.new(io).dimensions
    #     end
    #
    # You can also use methods for extracting the dimensions directly:
    #
    #     Shrine.extract_dimensions(io) # calls the defined analyzer
    #     #=> [300, 400]
    #
    #     Shrine.dimensions_analyzers[:fastimage].call(io) # calls a built-in analyzer
    #     #=> [300, 400]
    #
    # [fastimage]: https://github.com/sdsykes/fastimage
    # [image bombs]: https://www.bamsoftware.com/hacks/deflate.html
    module StoreDimensions
      def self.configure(uploader, opts = {})
        uploader.opts[:dimensions_analyzer] = opts.fetch(:analyzer, uploader.opts.fetch(:dimensions_analyzer, :fastimage))
      end

      module ClassMethods
        def extract_dimensions(io)
          analyzer = opts[:dimensions_analyzer]
          analyzer = dimensions_analyzers[analyzer] if analyzer.is_a?(Symbol)
          args = [io, dimensions_analyzers].take(analyzer.arity.abs)

          dimensions = analyzer.call(*args)
          io.rewind

          dimensions
        end

        def dimensions_analyzers
          @dimensions_analyzers ||= DimensionsAnalyzer::SUPPORTED_TOOLS.inject({}) do |hash, tool|
            hash.merge!(tool => DimensionsAnalyzer.new(tool).method(:call))
          end
        end
      end

      module InstanceMethods
        # We update the metadata with "width" and "height".
        def extract_metadata(io, context)
          width, height = extract_dimensions(io)

          super.update(
            "width"  => width,
            "height" => height,
          )
        end

        private

        # If the `io` is an uploaded file, copies its dimensions, otherwise
        # calls the predefined or custom analyzer.
        def extract_dimensions(io)
          self.class.extract_dimensions(io)
        end

        def dimensions_analyzers
          self.class.dimensions_analyzers
        end
      end

      module FileMethods
        def width
          Integer(metadata["width"]) if metadata["width"]
        end

        def height
          Integer(metadata["height"]) if metadata["height"]
        end

        def dimensions
          [width, height] if width || height
        end
      end

      class DimensionsAnalyzer
        SUPPORTED_TOOLS = [:fastimage]

        def initialize(tool)
          raise ArgumentError, "unsupported mime type analyzer tool: #{tool}" unless SUPPORTED_TOOLS.include?(tool)

          @tool = tool
        end

        def call(io)
          dimensions = send(:"extract_with_#{@tool}", io)
          io.rewind
          dimensions
        end

        private

        def extract_with_fastimage(io)
          require "fastimage"
          FastImage.size(io)
        end
      end
    end

    register_plugin(:store_dimensions, StoreDimensions)
  end
end
