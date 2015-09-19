class Shrine
  module Plugins
    module Versions
      def self.configure(uploader, names:)
        uploader.opts[:version_names] = names.map(&:to_s)
      end

      module ClassMethods
        def version_names
          opts[:version_names]
        end

        def versions!(hash)
          unknown_versions = hash.keys.map(&:to_s) - version_names
          unknown_versions.each { |name| raise Error, "unkown version: #{name.inspect}" }

          missing_versions = version_names - hash.keys.map(&:to_s)
          missing_versions.each { |name| raise Error, "missing version: #{name.inspect}" }

          hash
        end

        def versions(hash)
          hash.select { |key, value| version_names.include?(key) }
        end
      end

      module InstanceMethods
        def upload(io, context = {})
          if (hash = io).is_a?(Hash) && !hash.key?(:tempfile)
            self.class.versions!(hash).inject({}) do |versions, (name, version)|
              versions.update(name.to_s => super(version, version: name.to_s, **context))
            end
          else
            super
          end
        end

        def uploaded?(uploaded_file)
          if (hash = uploaded_file).is_a?(Hash)
            hash.all? { |name, version| super(version) }
          else
            super
          end
        end
      end

      module AttacherMethods
        def url(version = nil, **options)
          if get.is_a?(Hash)
            if version
              get.fetch(version.to_s).url(**options)
            else
              raise Error, "must call #{name}_url with the name of the version"
            end
          else
            if get || version.nil?
              super(**options)
            else
              default_url(options.merge(version: version.to_s))
            end
          end
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
            shrine_class.versions(hash).inject({}) do |versions, (name, data)|
              versions.update(name => super(data))
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
