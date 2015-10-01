class Shrine
  module Plugins
    module Versions
      def self.configure(uploader, names:)
        uploader.opts[:version_names] = names
      end

      module ClassMethods
        def version_names
          opts[:version_names]
        end

        def version?(name)
          version_names.map(&:to_s).include?(name.to_s)
        end

        def versions!(hash)
          hash.select do |name, version|
            version?(name) or raise Error, "unknown version: #{name.inspect}"
          end
        end

        def versions(hash)
          hash.select { |name, version| version?(name) }
        end

        def uploaded_file(object)
          if object.is_a?(Hash) && !object.key?("storage")
            result = {}
            versions(object).each { |name, data| result[name.to_sym] = super(data) }
            result
          else
            super
          end
        end
      end

      module InstanceMethods
        def uploaded?(uploaded_file)
          if (hash = uploaded_file).is_a?(Hash)
            hash.all? { |name, version| super(version) }
          else
            super
          end
        end

        private

        def _store(io, context)
          if (hash = io).is_a?(Hash)
            self.class.versions!(hash).inject({}) do |result, (name, version)|
              result.update(name => super(version, version: name, **context))
            end
          else
            super
          end
        end

        def _delete(uploaded_file, context)
          if (versions = uploaded_file).is_a?(Hash)
            versions.each { |name, version| super(version, version: name, **context) }
          else
            super
          end
        end
      end

      module AttacherMethods
        def url(version = nil, **options)
          if get.is_a?(Hash)
            if version
              raise Error, "unknown version: #{version.inspect}" if !shrine_class.version_names.include?(version)
              if file = get[version]
                file.url(**options)
              else
                default_url(options.merge(version: version))
              end
            else
              raise Error, "must call #{name}_url with the name of the version"
            end
          else
            if get || version.nil?
              super(**options)
            else
              default_url(options.merge(version: version))
            end
          end
        end

        def validate
          if validate_block && get.is_a?(Hash)
            raise Error, "cannot validate versions"
          else
            super
          end
        end
      end
    end

    register_plugin(:versions, Versions)
  end
end
