require "roda"
require "down"

class Shrine
  module Plugins
    # The download_endpoint plugin provides a [Roda] endpoint for downloading
    # uploaded files from specified storages. This can be useful when files
    # from your storages aren't accessible over URL (e.g. database storages) or
    # if you want to authenticate your downloads.
    #
    #     plugin :download_endpoint, storages: [:store], prefix: "attachments"
    #
    # After loading the plugin the endpoint should be mounted:
    #
    #     Rails.appliations.routes.draw do
    #       mount Shrine::DownloadEndpoint => "/attachments"
    #     end
    #
    # Now all stored files can be downloaded through the endpoint, and the
    # endpoint will efficiently stream the file from the storage when the
    # storage supports it. `UploadedFile#url` will automatically return the URL
    # to the endpoint for specified storages, so it's not needed to change the
    # code:
    #
    #     user.avatar.url #=> "/attachments/store/sdg0lsf8.jpg"
    #
    # :storages
    # :  An array of storage keys which the download endpoint should be used for.
    #
    # :prefix
    # :  The location where the download endpoint was mounted. If it was
    #    mounted at the root level, this should be set to nil.
    #
    # :host
    # :  The host that you want the download URLs to use (e.g. your app's domain
    #    name or a CDN). By default URLs are relative.
    #
    # :disposition
    # :  Can be set to "attachment" if you want that the user is always
    #    prompted to download the file when visiting the download URL.
    #    The default is "inline".
    #
    # This plugin is also suitable on Heroku when using FileSystem storage for
    # cache. On Heroku files cannot be stored to the "public" folder but rather
    # to the "tmp" folder, which means that by default it's not possible to
    # show the URL to the cached file. The download endpoint generates the URL
    # to any file, regardless of its location.
    #
    # [Roda]: https://github.com/jeremyevans/roda
    module DownloadEndpoint
      def self.configure(uploader, opts = {})
        uploader.opts[:download_endpoint_storages] = opts.fetch(:storages, uploader.opts[:download_endpoint_storages])
        uploader.opts[:download_endpoint_prefix] = opts.fetch(:prefix, uploader.opts[:download_endpoint_prefix])
        uploader.opts[:download_endpoint_disposition] = opts.fetch(:disposition, uploader.opts.fetch(:download_endpoint_disposition, "inline"))
        uploader.opts[:download_endpoint_host] = opts.fetch(:host, uploader.opts[:download_endpoint_host])

        raise Error, "The :storages option is required for download_endpoint plugin" if uploader.opts[:download_endpoint_storages].nil?

        uploader.assign_download_endpoint(App) unless uploader.const_defined?(:DownloadEndpoint)
      end

      module ClassMethods
        # Assigns the subclass a copy of the download endpoint class.
        def inherited(subclass)
          super
          subclass.assign_download_endpoint(self::DownloadEndpoint)
        end

        # Assigns the subclassed endpoint as the `DownloadEndpoint` constant.
        def assign_download_endpoint(klass)
          endpoint_class = Class.new(klass)
          endpoint_class.opts[:shrine_class] = self
          const_set(:DownloadEndpoint, endpoint_class)
        end
      end

      module FileMethods
        # Constructs the URL from the optional host, prefix, storage key and
        # uploaded file's id. For other uploaded files that aren't in the list
        # of storages it just returns their original URL.
        def url(**options)
          if shrine_class.opts[:download_endpoint_storages].include?(storage_key.to_sym)
            [
              shrine_class.opts[:download_endpoint_host],
              *shrine_class.opts[:download_endpoint_prefix],
              storage_key,
              id,
            ].join("/")
          else
            super
          end
        end
      end

      # Routes incoming requests. It first asserts that the storage is existent
      # and allowed. Afterwards it proceeds with the file download using
      # streaming.
      class App < Roda
        route do |r|
          r.on ":storage" do |storage_key|
            @storage = get_storage(storage_key)

            r.get /(.*)/ do |id|
              filename = request.path.split("/").last
              extname = File.extname(filename)

              response["Content-Disposition"] = "#{disposition}; filename=#{filename.inspect}"
              response["Content-Type"] = Rack::Mime.mime_type(extname)

              io = get_stream_io(id)
              response["Content-Length"] = io.size.to_s if io.size

              body = Enumerator.new do |y|
                if io.respond_to?(:each_chunk)
                  io.each_chunk { |chunk| y.yield(chunk) }
                else
                  y.yield io.read(16*1024, buffer ||= "") until io.eof?
                end
              end

              proxy = Rack::BodyProxy.new(body) do
                io.close
                io.delete if io.class.name == "Tempfile"
              end

              r.halt response.finish_with_body(proxy)
            end
          end
        end

        private

        attr_reader :storage

        def get_storage(storage_key)
          allow_storage!(storage_key)
          shrine_class.find_storage(storage_key)
        end

        def get_stream_io(id)
          if storage.respond_to?(:stream)
            warn "Storage#stream is deprecated, in Shrine 3 the download_endpoint plugin will use only Storage#open. You should update your storage library."
            stream = storage.enum_for(:stream, id)
            chunks = Enumerator.new { |y| y << Array(stream.next)[0] }
            Down::ChunkedIO.new(size: Array(stream.peek)[1], chunks: chunks)
          else
            storage.open(id)
          end
        end

        # Halts the request if storage is not allowed.
        def allow_storage!(storage_key)
          if !allowed_storages.map(&:to_s).include?(storage_key)
            error! 403, "Storage #{storage_key.inspect} is not allowed."
          end
        end

        # Halts the request with the error message.
        def error!(status, message)
          response.status = status
          response["Content-Type"] = "application/json"
          response.write({error: message}.to_json)
          request.halt
        end

        def disposition
          shrine_class.opts[:download_endpoint_disposition]
        end

        def allowed_storages
          shrine_class.opts[:download_endpoint_storages]
        end

        def shrine_class
          opts[:shrine_class]
        end
      end
    end

    register_plugin(:download_endpoint, DownloadEndpoint)
  end
end
