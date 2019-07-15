# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/store_dimensions.md] on GitHub.
    #
    # [doc/plugins/store_dimensions.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/store_dimensions.md
    module StoreDimensions
      LOG_SUBSCRIBER = -> (event) do
        Shrine.logger.info "Image Dimensions (#{event.duration}ms) – #{{
          io:       event[:io].class,
          uploader: event[:uploader],
        }.inspect}"
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:store_dimensions] ||= { analyzer: :fastimage, on_error: :warn, log_subscriber: LOG_SUBSCRIBER }
        uploader.opts[:store_dimensions].merge!(opts)

        # resolve error strategy
        case uploader.opts[:store_dimensions][:on_error]
        when :fail
          uploader.opts[:store_dimensions][:on_error] = -> (error) { fail error }
        when :warn
          uploader.opts[:store_dimensions][:on_error] = -> (error) { Shrine.warn "Error occurred when attempting to extract image dimensions: #{error.inspect}" }
        when :ignore
          uploader.opts[:store_dimensions][:on_error] = -> (error) { }
        end

        # instrumentation plugin integration
        if uploader.respond_to?(:subscribe)
          uploader.subscribe(:image_dimensions, &uploader.opts[:store_dimensions][:log_subscriber])
        end
      end

      module ClassMethods
        # Determines the dimensions of the IO object by calling the specified
        # analyzer.
        def extract_dimensions(io)
          analyzer = opts[:store_dimensions][:analyzer]
          analyzer = dimensions_analyzer(analyzer) if analyzer.is_a?(Symbol)
          args = [io, dimensions_analyzers].take(analyzer.arity.abs)

          dimensions = instrument_dimensions(io) { analyzer.call(*args) }
          io.rewind

          dimensions
        end
        alias dimensions extract_dimensions

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
          on_error = opts[:store_dimensions][:on_error]

          DimensionsAnalyzer.new(name, on_error: on_error).method(:call)
        end

        private

        # Sends "metadata_image_dimensions.shrine" events for instrumentation plugin.
        def instrument_dimensions(io, &block)
          return yield unless respond_to?(:instrument)

          instrument(:image_dimensions, io: io, &block)
        end
      end

      module InstanceMethods
        # We update the metadata with "width" and "height".
        def extract_metadata(io, context = {})
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

        def initialize(tool, on_error: method(:fail))
          raise Error, "unknown dimensions analyzer #{tool.inspect}, supported analyzers are: #{SUPPORTED_TOOLS.join(",")}" unless SUPPORTED_TOOLS.include?(tool)

          @tool     = tool
          @on_error = on_error
        end

        def call(io)
          dimensions = send(:"extract_with_#{@tool}", io)
          io.rewind
          dimensions
        end

        private

        def extract_with_fastimage(io)
          require "fastimage"
          FastImage.size(io, raise_on_failure: true)
        rescue FastImage::FastImageException => error
          on_error(error)
        end

        def extract_with_mini_magick(io)
          require "mini_magick"
          Shrine.with_file(io) { |file| MiniMagick::Image.new(file.path).dimensions }
        rescue MiniMagick::Error => error
          on_error(error)
        end

        def extract_with_ruby_vips(io)
          require "vips"
          Shrine.with_file(io) { |file| Vips::Image.new_from_file(file.path).size }
        rescue Vips::Error => error
          on_error(error)
        end

        def on_error(error)
          @on_error.call(error)
          nil
        end
      end
    end

    register_plugin(:store_dimensions, StoreDimensions)
  end
end
