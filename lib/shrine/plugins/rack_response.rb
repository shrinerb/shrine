# frozen_string_literal: true

require "rack"
require "content_disposition"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/rack_response.md] on GitHub.
    #
    # [doc/plugins/rack_response.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/rack_response.md
    module RackResponse
      module FileMethods
        # Returns a Rack response triple for the uploaded file.
        def to_rack_response(**options)
          FileResponse.new(self).call(**options)
        end
      end

      class FileResponse
        attr_reader :file

        def initialize(file)
          @file = file
        end

        # Returns a Rack response triple for the uploaded file.
        def call(**options)
          file.open unless file.opened?

          options[:range] = parse_content_range(options[:range]) if options[:range]

          status  = rack_status(**options)
          headers = rack_headers(**options)
          body    = rack_body(**options)

          [status, headers, body]
        end

        private

        # Returns "200 OK" on full request, and "206 Partial Content" on ranged
        # request.
        def rack_status(range: nil, **)
          range ? 206 : 200
        end

        # Returns a hash of "Content-Length", "Content-Type" and
        # "Content-Disposition" headers, whose values are extracted from
        # metadata. Also returns the correct "Content-Range" header on ranged
        # requests.
        def rack_headers(filename: nil, type: nil, disposition: "inline", range: false)
          length     = range ? range.size : file.size
          type     ||= file.mime_type || Rack::Mime.mime_type(".#{file.extension}")
          filename ||= file.original_filename || file.id.split("/").last

          headers = {}
          headers["Content-Length"]      = length.to_s if length
          headers["Content-Type"]        = type unless type == "application/octet-stream"
          headers["Content-Disposition"] = content_disposition(disposition, filename)
          headers["Content-Range"]       = "bytes #{range.begin}-#{range.end}/#{file.size}" if range
          headers["Accept-Ranges"]       = "bytes" unless range == false

          headers
        end

        # Returns an object that responds to #each and #close, which yields
        # contents of the file.
        def rack_body(range: nil, **)
          FileBody.new(file, range: range)
        end

        # Parses the value of a "Range" HTTP header.
        def parse_content_range(range_header)
          if Rack.release >= "2.0"
            ranges = Rack::Utils.get_byte_ranges(range_header, file.size)
          else
            ranges = Rack::Utils.byte_ranges({ "HTTP_RANGE" => range_header }, file.size)
          end

          ranges.first if ranges && ranges.one?
        end

        def content_disposition(disposition, filename)
          ContentDisposition.format(disposition: disposition, filename: filename)
        end
      end

      # Implements the interface of a Rack response body object.
      class FileBody
        attr_reader :file, :range

        def initialize(file, range: nil)
          @file  = file
          @range = range
        end

        # Streams the uploaded file directly from the storage.
        def each(&block)
          if range
            read_partial_chunks(&block)
          else
            read_chunks(&block)
          end
        end

        # Closes the file when response body is closed by the web server.
        def close
          file.close
        end

        # Rack::Sendfile is activated when response body responds to #to_path.
        def respond_to_missing?(name, include_private = false)
          name == :to_path && path
        end

        # Rack::Sendfile is activated when response body responds to #to_path.
        def method_missing(name, *args, &block)
          name == :to_path && path or super
        end

        private

        # Yields reasonably sized chunks of uploaded file's partial content
        # specified by the given index range.
        def read_partial_chunks
          bytes_read = 0

          read_chunks do |chunk|
            chunk_range = bytes_read..(bytes_read + chunk.bytesize - 1)

            if chunk_range.begin >= range.begin && chunk_range.end <= range.end
              yield chunk
            elsif chunk_range.end >= range.begin || chunk_range.end <= range.end
              requested_range_begin = [chunk_range.begin, range.begin].max - bytes_read
              requested_range_end   = [chunk_range.end, range.end].min - bytes_read

              yield chunk.byteslice(requested_range_begin..requested_range_end)
            else
              # skip chunk
            end

            bytes_read += chunk.bytesize
          end
        end

        # Yields reasonably sized chunks of uploaded file's content.
        def read_chunks
          if file.to_io.respond_to?(:each_chunk) # Down::ChunkedIO
            file.to_io.each_chunk { |chunk| yield chunk }
          else
            yield file.read(16*1024) until file.eof?
          end
        end

        # Returns actual path on disk when FileSystem storage is used.
        def path
          if defined?(Storage::FileSystem) && file.storage.is_a?(Storage::FileSystem)
            file.storage.path(file.id)
          end
        end
      end
    end

    register_plugin(:rack_response, RackResponse)
  end
end
