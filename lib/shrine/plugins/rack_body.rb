class Shrine
  module Plugins
    module RackBody
      module ClassMethods
        def rack_body(request)
          content_length = Integer(request.content_length) if request.content_length
          content_type   = request.content_type

          UploadedFile.new(request.body, content_length: content_length, content_type: content_type)
        end
      end

      class UploadedFile
        attr_reader :content_type

        def initialize(input, content_length: nil, content_type: nil)
          # if we don't know input size, we first copy its content to a tempfile
          input_size = calculate_size(input) unless content_length || input.respond_to?(:size)

          @input        = input
          @size         = content_length || input_size
          @content_type = content_type
          @bytes_read   = 0
        end

        def to_io
          @input
        end

        def read(*args)
          result = @input.read(*args)

          @bytes_read += result.bytesize if result
          fail EOFError, "bad content body" if (result.nil? || args.empty?) && !eof?

          result
        end

        def rewind
          @input.rewind
          @bytes_read = 0
        end

        def size
          if @size
            @size
          elsif @input.respond_to?(:size)
            @input.size
          end
        end

        def eof?
          @bytes_read == size
        end

        def close
          @input.close
        end

        private

        def calculate_size(io)
          size = IO.copy_stream(io, NullStream.new)
          io.rewind
          size
        end
      end

      class NullStream
        def write(data)
          data.bytesize
        end
      end
    end

    register_plugin(:rack_body, RackBody)
  end
end
