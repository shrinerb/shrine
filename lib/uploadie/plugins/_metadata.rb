class Uploadie
  module Plugins
    module Metadata
      module Helpers
        module_function

        def _extract_dimensions(io, library:)
          if io.respond_to?(:width) && io.respond_to?(:height)
            return [io.width, io.height]
          end

          case library
          when :mini_magick
            image = MiniMagick::Image.new(io.path)
            [image.width, image.height]
          when :rmagick
            image = Magick::Image.ping(io.path).first
            [image.columns, image.rows]
          when :dimensions
            if io.respond_to?(:path)
              Dimensions.dimensions(io.path)
            else
              Dimensions(io).dimensions
            end
          else
            raise Error, "dimensions library not supported: #{library.inspect}"
          end
        end

        def _extract_content_type(io)
          if io.respond_to?(:content_type)
            io.content_type
          elsif filename = _extract_filename(io)
            if defined?(MIME::Types)
              content_type = MIME::Types.of(filename).first
              content_type.to_s if content_type
            end
          end
        end

        def _extract_size(io)
          io.size
        end
      end
    end

    register_plugin(:_metadata, Metadata)
  end
end
