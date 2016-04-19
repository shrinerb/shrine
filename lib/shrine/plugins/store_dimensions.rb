class Shrine
  module Plugins
    # The store_dimensions plugin extracts and stores dimensions of the
    # uploaded image using the [fastimage] gem.
    #
    #     plugin :store_dimensions
    #
    # You can access the dimensions through `#width` and `#height` methods:
    #
    #     uploader = Shrine.new(:store)
    #     uploaded_file = uploader.upload(File.open("image.jpg"))
    #
    #     uploaded_file.width  #=> 300
    #     uploaded_file.height #=> 500
    #
    # The fastimage gem has built-in protection against [image bombs]. However,
    # if for some reason it doesn't suit your needs, you can provide a custom
    # `:analyzer`:
    #
    #     plugin :store_dimensions, analyzer: ->(io) do
    #       MiniMagick::Image.new(io).dimensions #=> [300, 500]
    #     end
    #
    # [fastimage]: https://github.com/sdsykes/fastimage
    # [image bombs]: https://www.bamsoftware.com/hacks/deflate.html
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
          analyzer = opts[:dimensions_analyzer]
          analyzer = method(:"_extract_dimensions_with_#{analyzer}") if analyzer.is_a?(Symbol)

          dimensions = analyzer.call(io)
          io.rewind

          dimensions
        end

        def _extract_dimensions_with_fastimage(io)
          FastImage.size(io)
        end
      end

      module FileMethods
        def width
          Integer(metadata["width"]) if metadata["width"]
        end

        def height
          Integer(metadata["height"]) if metadata["height"]
        end
      end
    end

    register_plugin(:store_dimensions, StoreDimensions)
  end
end
