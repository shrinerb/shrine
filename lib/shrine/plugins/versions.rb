# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/versions.md] on GitHub.
    #
    # [doc/plugins/versions.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/versions.md
    module Versions
      def self.load_dependencies(uploader, *)
        uploader.plugin :default_url
      end

      def self.configure(uploader, opts = {})
        Shrine.deprecation("The versions Shrine plugin doesn't need the :names option anymore, you can safely remove it.") if opts.key?(:names)

        uploader.opts[:version_names] = opts.fetch(:names, uploader.opts[:version_names])
        uploader.opts[:version_fallbacks] = opts.fetch(:fallbacks, uploader.opts.fetch(:version_fallbacks, {}))
        uploader.opts[:versions_fallback_to_original] = opts.fetch(:fallback_to_original, uploader.opts.fetch(:versions_fallback_to_original, true))
      end

      module ClassMethods
        def version_names
          Shrine.deprecation("Shrine.version_names is deprecated and will be removed in Shrine 3.")
          opts[:version_names]
        end

        def version_fallbacks
          opts[:version_fallbacks]
        end

        # Checks that the identifier is a registered version.
        def version?(name)
          Shrine.deprecation("Shrine.version? is deprecated and will be removed in Shrine 3.")
          version_names.nil? || version_names.map(&:to_s).include?(name.to_s)
        end

        # Converts a hash of data into a hash of versions.
        def uploaded_file(object, &block)
          if object.is_a?(Hash) && object.values.none? { |value| value.is_a?(String) }
            object.inject({}) do |result, (name, value)|
              result.merge!(name.to_sym => uploaded_file(value, &block))
            end
          elsif object.is_a?(Array)
            object.map { |value| uploaded_file(value, &block) }
          else
            super
          end
        end
      end

      module InstanceMethods
        # Checks whether all versions are uploaded by this uploader.
        def uploaded?(object)
          if object.is_a?(Hash)
            object.all? { |name, version| uploaded?(version) }
          elsif object.is_a?(Array)
            object.all? { |version| uploaded?(version) }
          else
            super
          end
        end

        private

        # Stores each version individually. It asserts that all versions are
        # known, because later the versions will be silently filtered, so
        # we want to let the user know that they forgot to register a new
        # version.
        def _store(io, context)
          if (hash = io).is_a?(Hash)
            raise Error, ":location is not applicable to versions" if context.key?(:location)
            raise Error, "detected multiple versions that point to the same IO object: given versions: #{hash.keys}, unique versions: #{hash.invert.invert.keys}" if hash.invert.invert != hash

            hash.inject({}) do |result, (name, value)|
              result.merge!(name.to_sym => _store(value, context.merge(version: name.to_sym){|_, v1, v2| Array(v1) + Array(v2)}))
            end
          elsif (array = io).is_a?(Array)
            array.map.with_index { |value, idx| _store(value, context.merge(version: idx){|_, v1, v2| Array(v1) + Array(v2)}) }
          else
            super
          end
        end

        # Deletes each file individually
        def _delete(uploaded_file, context)
          if (hash = uploaded_file).is_a?(Hash)
            hash.each do |name, value|
              _delete(value, context)
            end
          elsif (array = uploaded_file).is_a?(Array)
            array.each do |value|
              _delete(value, context)
            end
          else
            super
          end
        end
      end

      module AttacherMethods
        # Smart versioned URLs, which include the version name in the default
        # URL, and properly forwards any options to the underlying storage.
        def url(version = nil, **options)
          attachment = get

          if attachment.is_a?(Hash)
            if version
              version = version.to_sym
              if attachment.key?(version)
                attachment[version].url(**options)
              elsif fallback = shrine_class.version_fallbacks[version]
                url(fallback, **options)
              else
                default_url(**options, version: version)
              end
            else
              raise Error, "must call Shrine::Attacher#url with the name of the version"
            end
          else
            if version
              if attachment && fallback_to_original?
                attachment.url(**options)
              else
                default_url(**options, version: version)
              end
            else
              super(**options)
            end
          end
        end

        private

        def fallback_to_original?
          shrine_class.opts[:versions_fallback_to_original]
        end

        # Converts the Hash/Array of UploadedFile objects into a Hash/Array of data.
        def convert_to_data(object)
          if object.is_a?(Hash)
            object.inject({}) do |hash, (name, value)|
              hash.merge!(name => convert_to_data(value))
            end
          elsif object.is_a?(Array)
            object.map { |value| convert_to_data(value) }
          else
            super
          end
        end
      end
    end

    register_plugin(:versions, Versions)
  end
end
