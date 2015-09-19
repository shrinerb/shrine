require "roda"

class Shrine
  module Plugins
    module Endpoint
      def self.load_dependencies(uploader, *)
        uploader.plugin :rack_file
      end

      def self.configure(uploader, allowed_storages: [:cache], return_url: false, max_size: nil)
        allowed_storages = allowed_storages.map { |key| uploader.storage(key) }
        uploader.opts[:endpoint_allowed_storages] = allowed_storages
        uploader.opts[:endpoint_return_url] = return_url
        uploader.opts[:endpoint_max_size] = max_size
      end

      module ClassMethods
        def endpoint
          @endpoint ||= build_endpoint
        end

        private

        def build_endpoint
          app = Class.new(App)
          app.opts[:shrine_class] = self
          app.app
        end
      end

      module InstanceMethods
        private

        def _upload(io, context)
          uploaded_file = super
          uploaded_file.data.update("url" => uploaded_file.url) if opts[:endpoint_return_url]
          uploaded_file
        end
      end

      class App < Roda
        plugin :json, classes: [Hash, Array, Shrine::UploadedFile]
        plugin :halt

        route do |r|
          r.on ":storage" do |storage_key|
            allow_storage!(storage_key)
            @uploader = shrine_class.new(storage_key)

            r.post ":name" do |name|
              file = get_file
              context = {name: name}

              @uploader.upload(file, context)
            end
          end
        end

        def allow_storage!(storage_key)
          storage = shrine_class.storages[storage_key]
          if !allowed_storages.include?(storage)
            error! 403, "Storage #{storage_key.inspect} is not allowed."
          end
        end

        def get_file
          file = require_param!("file")
          error! 400, "The \"file\" query parameter is not a file." if !(file.is_a?(Hash) && file.key?(:tempfile))
          check_filesize!(file[:tempfile])

          file
        end

        def check_filesize!(file)
          if max_size && file.size > max_size * 1024 * 1024
            file.delete
            error! 413, "The file is too big (maximum size is #{max_size} MB)."
          end
        end

        def require_param!(name)
          request.params.fetch(name)
        rescue KeyError
          error! 400, "Missing query parameter: #{name.inspect}"
        end

        def error!(status, message)
          request.halt status, {error: message}
        end

        def shrine_class
          opts[:shrine_class]
        end

        def allowed_storages
          shrine_class.opts[:endpoint_allowed_storages]
        end

        def max_size
          shrine_class.opts[:endpoint_max_size]
        end
      end
    end

    register_plugin(:endpoint, Endpoint)
  end
end
