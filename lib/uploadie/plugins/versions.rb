class Uploadie
  module Plugins
    module Versions
      def self.load_dependencies(uploadie)
        uploadie.plugin :multiple_files
      end

      module InstanceMethods
        def upload(io, type = nil)
          if io.is_a?(Hash)
            upload_versions(io, type) { |ios, locations| super(ios, locations) }
          else
            super
          end
        end

        def store(io, type = nil)
          if io.is_a?(Hash)
            upload_versions(io, type) { |ios, locations| super(ios, locations) }
          else
            super
          end
        end

        private

        def upload_versions(hash, type)
          ios       = hash.values
          locations = hash.map { |name, io| generate_location(io: io, type: type, version: name) }
          names     = hash.keys

          uploaded_files = yield(ios, locations)

          Hash[names.zip(uploaded_files)]
        end
      end
    end

    register_plugin(:versions, Versions)
  end
end
