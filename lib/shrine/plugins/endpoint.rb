require "roda"

class Shrine
  module Plugins
    module Endpoint
      def self.load_dependencies(uploader, *)
        uploader.plugin :rack_file
      end

      def self.configure(uploader, allowed_storages: [:cache], return_url: false, max_size: nil)
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

      class App < Roda
        plugin :default_headers, "Content-Type"=>"application/json"
        plugin :halt

        route do |r|
          r.on ":storage" do |storage_key|
            allow_storage!(storage_key)
            @uploader = shrine_class.new(storage_key.to_sym)

            r.post ":name" do |name|
              file = get_file
              context = {name: name}

              json @uploader.upload(file, context)
            end
          end
        end

        def json(object)
          serialize(object).to_json
        end

        def serialize(object)
          case object
          when shrine_class::UploadedFile
            hash = {"data" => object.data}
            hash["url"] = object.url if shrine_class.opts[:endpoint_return_url]
            hash
          when Hash
            object.each { |key, value| object[key] = serialize(value) }
          when Array
            object.map { |item| serialize(item) }
          end
        end

        def allow_storage!(storage)
          if !allowed_storages.map(&:to_s).include?(storage)
            error! 403, "Storage #{storage.inspect} is not allowed."
          end
        end

        def get_file
          file = require_param!("file")
          error! 400, "The \"file\" query parameter is not a file." if !(file.is_a?(Hash) && file.key?(:tempfile))
          check_filesize!(file[:tempfile])

          file
        end

        def check_filesize!(file)
          if max_size && file.size > max_size
            file.delete
            megabytes = max_size.to_f / 1024 / 1024
            error! 413, "The file is too big (maximum size is #{megabytes} MB)."
          end
        end

        def require_param!(name)
          request.params.fetch(name)
        rescue KeyError
          error! 400, "Missing query parameter: #{name.inspect}"
        end

        def error!(status, message)
          request.halt status, {error: message}.to_json
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
