require "rack"

class Shrine
  module Plugins
    # The `rack_response` plugin allows you to convert an `UploadedFile` object
    # into a triple consisting of status, headers, and body, suitable for
    # returning as a response in a Rack-based application.
    #
    #     plugin :rack_response
    #
    # To convert a `Shrine::UploadedFile` into a Rack response, simply call
    # `#to_rack_response`:
    #
    #     status, headers, body = uploaded_file.to_rack_response
    #     status  #=> 200
    #     headers #=>
    #     # {
    #     #   "Content-Length"      => "100",
    #     #   "Content-Type"        => "text/plain",
    #     #   "Content-Disposition" => "inline; filename=\"file.txt\"",
    #     #   "Accept-Ranges"       => "bytes"
    #     # }
    #     body    # object that responds to #each and #close
    #
    # An example how this can be used in a Rails controller:
    #
    #     class FilesController < ActionController::Base
    #       def download
    #         # ...
    #         file_response = record.attachment.to_rack_response
    #
    #         response.status = file_response[0]
    #         response.headers.merge!(file_response[1])
    #         self.response_body = file_response[2]
    #       end
    #     end
    #
    # ## Disposition
    #
    # By default the "Content-Disposition" header will use the `inline`
    # disposition, but you can change it to `attachment` if you don't want the
    # file to be rendered inside the browser:
    #
    #     status, headers, body = uploaded_file.to_rack_response(disposition: "attachment")
    #     headers["Content-Disposition"] #=> "attachment; filename=\"file.txt\""
    #
    # ## Range
    #
    # Partial responses are also supported via the `:range` parameter, which
    # accepts a value of the `Range` request header.
    #
    #     status, headers, body = uploaded_file.to_rack_response(range: "bytes=100-200")
    #     status                    #=> 206
    #     headers["Content-Length"] #=> "101"
    #     headers["Content-Range"]  #=> "bytes 100-200/1000"
    #     body                      # partial content
    module RackResponse
      module FileMethods
        # Returns a Rack response triple for the uploaded file.
        def to_rack_response(disposition: "inline", range: nil)
          range = parse_http_range(range) if range

          status  = range ? 206 : 200
          headers = rack_headers(disposition: disposition, range: range)
          body    = rack_body(range: range)

          [status, headers, body]
        end

        private

        # Returns a hash of "Content-Length", "Content-Type" and
        # "Content-Disposition" headers, whose values are extracted from
        # metadata. Also returns the correct "Content-Range" header on ranged
        # requests.
        def rack_headers(disposition:, range: nil)
          length   = range ? range.end - range.begin + 1 : size || io.size
          type     = mime_type || Rack::Mime.mime_type(".#{extension}")
          filename = original_filename || id.split("/").last

          headers = {}
          headers["Content-Length"]      = length.to_s if length
          headers["Content-Type"]        = type
          headers["Content-Disposition"] = "#{disposition}; filename=\"#{filename}\""
          headers["Content-Range"]       = "bytes #{range.begin}-#{range.end}/#{size||io.size}" if range
          headers["Accept-Ranges"]       = "bytes"

          headers
        end

        # Returns an object that responds to #each and #close, which yields
        # contents of the file.
        def rack_body(range: nil)
          if range
            body = enum_for(:read_partial_chunks, range)
          else
            body = enum_for(:read_chunks)
          end

          Rack::BodyProxy.new(body) { io.close }
        end

        # Yields reasonably sized chunks of uploaded file's partial content
        # specified by the given index range.
        def read_partial_chunks(range)
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
          if io.respond_to?(:each_chunk) # Down::ChunkedIO
            io.each_chunk { |chunk| yield chunk }
          else
            yield io.read(16*1024) until io.eof?
          end
        end

        # Parses the value of a "Range" HTTP header.
        def parse_http_range(range_header)
          if Rack.release >= "2.0"
            ranges = Rack::Utils.get_byte_ranges(range_header, size || io.size)
          else
            ranges = Rack::Utils.byte_ranges({"HTTP_RANGE" => range_header}, size || io.size)
          end

          ranges.first if ranges && ranges.one?
        end
      end
    end

    register_plugin(:rack_response, RackResponse)
  end
end
