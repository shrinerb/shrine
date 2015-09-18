require "roda"

class Uploadie
  module Plugins
    module Endpoint
      def self.load_dependencies(uploader, *)
        uploader.plugin :rack_file
      end

      def self.configure(uploader, allowed_storages: [:cache])
        uploader.opts[:endpoint_allowed_storages] = allowed_storages
      end

      module ClassMethods
        def endpoint
          @endpoint ||= build_endpoint
        end

        private

        def build_endpoint
          app = Class.new(App)
          app.opts[:uploadie_class] = self
          app.app
        end
      end

      class App < Roda
        plugin :json, classes: [Hash, Array, Uploadie::UploadedFile]
        plugin :halt
        plugin :error_handler

        route do |r|
          r.on ":storage" do |storage|
            allow_storage!(storage.to_sym)
            @uploader = uploadie_class.new(storage.to_sym)

            r.post ":name" do |name|
              file = require_param!("file")
              context = {name: name.to_sym}

              @uploader.upload(file, context)
            end
          end
        end

        error do |exception|
          if exception.is_a?(Uploadie::InvalidFile)
            error! 400, "The \"file\" query parameter is not a file."
          end
        end

        def allow_storage!(storage)
          if !allowed_storages.include?(storage)
            error! 403, "Storage :#{storage} is not allowed."
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

        def uploadie_class
          opts[:uploadie_class]
        end

        def allowed_storages
          uploadie_class.opts[:endpoint_allowed_storages]
        end
      end
    end

    register_plugin(:endpoint, Endpoint)
  end
end
