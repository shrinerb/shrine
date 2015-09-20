require "open-uri"
require "tempfile"
require "uri"

class Shrine
  module Utils
    module_function

    DOWNLOAD_ERRORS = [
      SocketError,        # domain not found
      OpenURI::HTTPError, # response status 4xx or 5xx
      RuntimeError,       # redirection errors (e.g. redirection loop)
    ]

    def download(url)
      url = URI.encode(URI.decode(url))
      downloaded_file = URI(url).open("User-Agent"=>"Shrine/#{Shrine.version.to_s}")

      # open-uri will return a StringIO instead of a Tempfile if the filesize
      # is less than 10 KB (ಠ_ಠ), so we patch this behaviour by converting it
      # into a Tempfile.
      if downloaded_file.is_a?(StringIO)
        stringio = downloaded_file
        downloaded_file = copy_to_tempfile("open-uri", downloaded_file)
        OpenURI::Meta.init downloaded_file, stringio
      end

      DownloadedFile.new(downloaded_file)

    rescue *DOWNLOAD_ERRORS => error
      raise Error, "download failed (#{url}): #{error.message}"
    end

    def copy_to_tempfile(basename, io)
      Tempfile.new(basename, binmode: true).tap do |tempfile|
        IO.copy_stream(io, tempfile.path)
      end
    end

    class DownloadedFile < DelegateClass(Tempfile)
      def original_filename
        path = __getobj__.base_uri.path
        path = URI.decode(path)
        File.basename(path) unless path.empty?
      end

      def content_type
        __getobj__.content_type
      end
    end
  end
end
