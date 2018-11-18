# frozen_string_literal: true

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
    #         set_rack_response record.attachment.to_rack_response
    #       end
    #
    #       private
    #
    #       def set_rack_response((status, headers, body))
    #         self.status = status
    #         self.headers.merge!(headers)
    #         self.response_body = body
    #       end
    #     end
    #
    # The `#each` method on the response body object will stream the uploaded
    # file directly from the storage. It also works with [Rack::Sendfile] when
    # using `FileSystem` storage.
    #
    # ## Type
    #
    # The response `Content-Type` header will default to the value of the
    # `mime_type` metadata. A custom content type can be provided via the
    # `:type` option:
    #
    #     _, headers, _ uploaded_file.to_rack_response(type: "text/plain; charset=utf-8")
    #     headers["Content-Type"] #=> "text/plain; charset=utf-8"
    #
    # ## Filename
    #
    # The download filename in the `Content-Disposition` header will default to
    # the value of the `filename` metadata. A custom download filename can be
    # provided via the `:filename` option:
    #
    #     _, headers, _ uploaded_file.to_rack_response(filename: "my-filename.txt")
    #     headers["Content-Disposition"] #=> "inline; filename=\"my-filename.txt\""
    #
    # ## Disposition
    #
    # The default disposition in the "Content-Disposition" header is `inline`,
    # but it can be changed via the `:disposition` option:
    #
    #     _, headers, _ = uploaded_file.to_rack_response(disposition: "attachment")
    #     headers["Content-Disposition"] #=> "attachment; filename=\"file.txt\""
    #
    # ## Range
    #
    # [Partial responses][range requests] are also supported via the `:range`
    # option, which accepts a value of the `Range` request header.
    #
    #     env["HTTP_RANGE"] #=> "bytes=100-200"
    #     status, headers, body = uploaded_file.to_rack_response(range: env["HTTP_RANGE"])
    #     status                    #=> 206
    #     headers["Content-Length"] #=> "101"
    #     headers["Content-Range"]  #=> "bytes 100-200/1000"
    #     body                      # partial content
    #
    # [range requests]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Range_requests
    # [Rack::Sendfile]: https://www.rubydoc.info/github/rack/rack/Rack/Sendfile
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
          length     = range ? range.size : size
          type     ||= @file.mime_type || Rack::Mime.mime_type(".#{@file.extension}")
          filename ||= @file.original_filename || @file.id.split("/").last

          headers = {}
          headers["Content-Length"]      = length.to_s if length
          headers["Content-Type"]        = type
          headers["Content-Disposition"] = "#{disposition}; filename=\"#{filename}\""
          headers["Content-Range"]       = "bytes #{range.begin}-#{range.end}/#{size}" if range
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
            ranges = Rack::Utils.get_byte_ranges(range_header, size)
          else
            ranges = Rack::Utils.byte_ranges({"HTTP_RANGE" => range_header}, size)
          end

          ranges.first if ranges && ranges.one?
        end

        # Read size from metadata, otherwise retrieve the size from the storage.
        def size
          @file.size || @file.to_io.size
        end
      end

      # Implements the interface of a Rack response body object.
      class FileBody
        def initialize(file, range: nil)
          @file  = file
          @range = range
        end

        # Streams the uploaded file directly from the storage.
        def each(&block)
          if @range
            read_partial_chunks(&block)
          else
            read_chunks(&block)
          end
        end

        # Closes the file when response body is closed by the web server.
        def close
          @file.close
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

            if chunk_range.begin >= @range.begin && chunk_range.end <= @range.end
              yield chunk
            elsif chunk_range.end >= @range.begin || chunk_range.end <= @range.end
              requested_range_begin = [chunk_range.begin, @range.begin].max - bytes_read
              requested_range_end   = [chunk_range.end, @range.end].min - bytes_read

              yield chunk.byteslice(requested_range_begin..requested_range_end)
            else
              # skip chunk
            end

            bytes_read += chunk.bytesize
          end
        end

        # Yields reasonably sized chunks of uploaded file's content.
        def read_chunks
          if @file.to_io.respond_to?(:each_chunk) # Down::ChunkedIO
            @file.to_io.each_chunk { |chunk| yield chunk }
          else
            yield @file.read(16*1024) until @file.eof?
          end
        end

        # Returns actual path on disk when FileSystem storage is used.
        def path
          if defined?(Storage::FileSystem) && @file.storage.is_a?(Storage::FileSystem)
            @file.storage.path(@file.id)
          end
        end
      end
    end

    register_plugin(:rack_response, RackResponse)
  end
end
