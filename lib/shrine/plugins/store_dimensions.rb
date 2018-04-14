# frozen_string_literal: true

class Shrine
  module Plugins
    # The `store_dimensions` plugin extracts dimensions of uploaded images and
    # stores them into the metadata hash.
    #
    #     plugin :store_dimensions
    #
    # The dimensions are stored as "width" and "height" metadata values on the
    # Shrine::UploadedFile object. For convenience the plugin also adds
    # `#width`, `#height` and `#dimensions` reader methods.
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
    # By default the [fastimage] gem is used to extract dimensions. You can
    # choose a different built-in analyzer via the `:analyzer` option:
    #
    #     plugin :store_dimensions, analyzer: :mini_magick
    #
    # The following analyzers are supported:
    #
    # :fastimage
    # : (Default). Uses the [FastImage] gem to extract dimensions from any IO
    #   object.
    #
    # :mini_magick
    # : Uses the [MiniMagick] gem to extract dimensions from File objects. If
    #   non-file IO object is given it will be temporarily downloaded to disk.
    #
    # :ruby_vips
    # : Uses the [ruby-vips] gem to extract dimensions from File objects. If
    #   non-file IO object is given it will be temporarily downloaded to disk.
    #
    # You can also create your own custom dimensions analyzer, where you can
    # reuse any of the built-in analyzers. The analyzer is a lambda that
    # accepts an IO object and returns width and height as a two-element array,
    # or `nil` if dimensions could not be extracted.
    #
    #     plugin :store_dimensions, analyzer: -> (io, analyzers) do
    #       dimensions   = analyzers[:fastimage].call(io)   # try extracting dimensions with FastImage
    #       dimensions ||= analyzers[:mini_magick].call(io) # otherwise fall back to MiniMagick
    #       dimensions
    #     end
    #
    # You can use methods for extracting the dimensions directly:
    #
    #     # or YourUploader.extract_dimensions(io)
    #     Shrine.extract_dimensions(io) # calls the defined analyzer
    #     #=> [300, 400]
    #
    #     # or YourUploader.dimensions_analyzers
    #     Shrine.dimensions_analyzers[:fastimage].call(io) # calls a built-in analyzer
    #     #=> [300, 400]
    #
    # [FastImage]: https://github.com/sdsykes/fastimage
    # [MiniMagick]: https://github.com/minimagick/minimagick
    # [ruby-vips]: https://github.com/jcupitt/ruby-vips
    module StoreDimensions
      def self.configure(uploader, opts = {})
        uploader.opts[:dimensions_analyzer] = opts.fetch(:analyzer, uploader.opts.fetch(:dimensions_analyzer, :fastimage))
      end

      module ClassMethods
        # Determines the dimensions of the IO object by calling the specified
        # analyzer.
        def extract_dimensions(io)
          analyzer = opts[:dimensions_analyzer]
          analyzer = dimensions_analyzer(analyzer) if analyzer.is_a?(Symbol)
          args = [io, dimensions_analyzers].take(analyzer.arity.abs)

          dimensions = analyzer.call(*args)
          io.rewind

          dimensions
        end

        # Returns a hash of built-in dimensions analyzers, where keys are
        # analyzer names and values are `#call`-able objects which accepts the
        # IO object.
        def dimensions_analyzers
          @dimensions_analyzers ||= DimensionsAnalyzer::SUPPORTED_TOOLS.inject({}) do |hash, tool|
            hash.merge!(tool => dimensions_analyzer(tool))
          end
        end

        # Returns callable dimensions analyzer object.
        def dimensions_analyzer(name)
          DimensionsAnalyzer.new(name).method(:call)
        end
      end

      module InstanceMethods
        # We update the metadata with "width" and "height".
        def extract_metadata(io, context)
          width, height = extract_dimensions(io)

          super.merge!("width" => width, "height" => height)
        end

        private

        # Extracts dimensions using the specified analyzer.
        def extract_dimensions(io)
          self.class.extract_dimensions(io)
        end

        # Returns a hash of built-in dimensions analyzers.
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
        SUPPORTED_TOOLS = [:fastimage, :mini_magick, :ruby_vips]

        def initialize(tool)
          raise Error, "unknown dimensions analyzer #{tool.inspect}, supported analyzers are: #{SUPPORTED_TOOLS.join(",")}" unless SUPPORTED_TOOLS.include?(tool)

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

        def extract_with_mini_magick(io)
          require "mini_magick"
          ensure_file(io) { |file| MiniMagick::Image.new(file.path).dimensions }
        rescue MiniMagick::Error
        end

        def extract_with_ruby_vips(io)
          require "vips"
          ensure_file(io) { |file| Vips::Image.new_from_file(file.path).size }
        rescue Vips::Error
        end

        def ensure_file(io)
          if io.respond_to?(:path)
            yield io
          else
            Tempfile.create("shrine-store_dimensions") do |tempfile|
              IO.copy_stream(io, tempfile.path)
              yield tempfile
            end
          end
        end
      end
    end

    register_plugin(:store_dimensions, StoreDimensions)
  end
end
