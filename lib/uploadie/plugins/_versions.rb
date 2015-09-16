class Uploadie
  module Plugins
    module Versions
      module InstanceMethods
        def upload(io, context = {})
          if (hash = io).is_a?(Hash) && !hash.key?(:tempfile)
            hash.inject({}) do |versions, (name, version)|
              versions.update(name => super(version, version: name, **context))
            end
          else
            super
          end
        end

        def uploaded?(uploaded_file)
          if (versions = uploaded_file).is_a?(Hash)
            versions.all? { |name, version| super(version) }
          else
            super
          end
        end
      end

      module AttacherMethods
        def url(version = nil)
          if get.is_a?(Hash)
            if version
              get.fetch(version).url
            else
              raise Error, "must call #{name}_url with the name of the version"
            end
          else
            super
          end
        end

        def default_url(version = nil)
          store.default_url(name: name, record: record, version: version)
        end

        def validate!
          if validate_block && get.is_a?(Hash)
            raise Error, "cannot validate versions"
          else
            super
          end
        end

        private

        def uploaded_file(hash)
          if hash.key?("storage")
            super
          else
            hash.inject({}) do |versions, (name, data)|
              versions.update(name.to_sym => super(data))
            end
          end
        end

        def data(uploaded_file)
          if (versions = uploaded_file).is_a?(Hash)
            versions.inject({}) do |hash, (name, version)|
              hash.update(name => super(version))
            end
          else
            super
          end
        end

        def delete!(uploaded_file)
          if (versions = uploaded_file).is_a?(Hash)
            versions.each { |name, uploaded_file| super(uploaded_file) }
          else
            super
          end
        end
      end
    end

    register_plugin(:_versions, Versions)
  end
end
