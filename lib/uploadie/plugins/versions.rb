class Uploadie
  module Plugins
    module Versions
      def self.load_dependencies(uploadie)
        uploadie.plugin :multiple_files
      end

      module InstanceMethods
        def upload(io, context = {})
          if io.is_a?(Hash)
            upload_versions(io, context) { |ios, contexts| super(ios, contexts) }
          else
            super
          end
        end

        def store(io, context = {})
          if io.is_a?(Hash)
            upload_versions(io, context) { |ios, contexts| super(ios, contexts) }
          else
            super
          end
        end

        private

        def upload_versions(hash, context)
          versions = hash.values
          names    = hash.keys
          contexts = names.map { |name| context.merge(version: name) }

          uploaded_files = yield(versions, contexts)

          Hash[names.zip(uploaded_files)]
        end
      end
    end

    register_plugin(:versions, Versions)
  end
end
