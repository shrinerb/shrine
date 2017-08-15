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
    #     headers #=> {"Content-Length" => "100", "Content-Type" => "text/plain", "Content-Disposition" => "inline; filename=\"file.txt\""}
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
    # By default the "Content-Disposition" header will use the `inline`
    # disposition, but you can change it to `attachment` if you don't want the
    # file to be rendered inside the browser:
    #
    #     status, headers, body = uploaded_file.to_rack_response(disposition: "attachment")
    #     headers["Content-Disposition"] #=> "attachment; filename=\"file.txt\""
    module RackResponse
      module FileMethods
        # Returns a Rack response triple for the uploaded file.
        def to_rack_response(disposition: "inline")
          status  = 200
          headers = rack_headers(disposition: disposition)
          body    = rack_body

          [status, headers, body]
        end

        private

        # Returns a hash of "Content-Length", "Content-Type", and
        # "Content-Disposition" headers, whose values are extracted from
        # metadata.
        def rack_headers(disposition:)
          length   = size || io.size
          type     = mime_type || Rack::Mime.mime_type(".#{extension}")
          filename = original_filename || id.split("/").last

          headers = {}
          headers["Content-Length"]      = length.to_s if length
          headers["Content-Type"]        = type
          headers["Content-Disposition"] = "#{disposition}; filename=\"#{filename}\""

          headers
        end

        # Returns an object that responds to #each and #close, which yields
        # contents of the file.
        def rack_body
          chunks = Enumerator.new do |yielder|
            if io.respond_to?(:each_chunk) # Down::ChunkedIO
              io.each_chunk { |chunk| yielder << chunk }
            else
              yielder << io.read(16*1024) until io.eof?
            end
          end

          Rack::BodyProxy.new(chunks) { io.close }
        end
      end
    end

    register_plugin(:rack_response, RackResponse)
  end
end
