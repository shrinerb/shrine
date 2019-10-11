# frozen_string_literal: true

Shrine.deprecation("The versions plugin is deprecated and will be removed in Shrine 4. Use the new derivatives plugin instead.")

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/versions
    module Versions
      def self.load_dependencies(uploader, **)
        uploader.plugin :processing
        uploader.plugin :default_url
      end

      def self.configure(uploader, **opts)
        uploader.opts[:versions] ||= { fallbacks: {}, fallback_to_original: true }
        uploader.opts[:versions].merge!(opts)
      end

      module ClassMethods
        def version_fallbacks
          opts[:versions][:fallbacks]
        end

        # Converts a hash of data into a hash of versions.
        def uploaded_file(object)
          object = JSON.parse(object) if object.is_a?(String)

          Utils.deep_map(object, transform_keys: :to_sym) do |path, value|
            if value.is_a?(Hash) && (value["id"].is_a?(String) || value[:id].is_a?(String))
              file = super(value)
            elsif value.is_a?(UploadedFile)
              file = value
            end

            if file
              yield file if block_given?
              file
            end
          end
        end
      end

      module InstanceMethods
        def upload(io, **options)
          files = process(io, **options) || io

          Utils.map_file(files) do |name, version|
            options.merge!(version: name.one? ? name.first : name) if name

            super(version, **options, process: false)
          end
        end
      end

      module AttacherMethods
        def destroy(*)
          Utils.each_file(self.file) { |_, file| file.delete }
        end

        # Smart versioned URLs, which include the version name in the default
        # URL, and properly forwards any options to the underlying storage.
        def url(version = nil, **options)
          if file.is_a?(Hash)
            if version
              version = version.to_sym
              if file.key?(version)
                file[version].url(**options)
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
              if file && shrine_class.opts[:versions][:fallback_to_original]
                file.url(**options)
              else
                default_url(**options, version: version)
              end
            else
              super(**options)
            end
          end
        end

        # Converts the Hash/Array of UploadedFile objects into a Hash/Array of data.
        def data
          Utils.map_file(file, transform_keys: :to_s) do |_, version|
            version.data
          end
        end

        def file=(file)
          if file.is_a?(Hash) || file.is_a?(Array)
            @file = file
          else
            super
          end
        end

        def uploaded_file(value, &block)
          shrine_class.uploaded_file(value, &block)
        end

        private

        def uploaded?(file, storage_key)
          if file.is_a?(Hash) || file.is_a?(Array)
            Utils.each_file(file).all? { |_, f| f.storage_key == storage_key }
          else
            super
          end
        end
      end

      module Utils
        module_function

        def each_file(object)
          return enum_for(__method__, object) unless block_given?

          map_file(object) do |path, file|
            yield path, file
            file
          end
        end

        def map_file(object, transform_keys: :to_sym)
          if object.is_a?(Hash) || object.is_a?(Array)
            deep_map(object, transform_keys: transform_keys) do |path, value|
              yield path, value unless value.is_a?(Hash) || value.is_a?(Array)
            end
          elsif object
            yield nil, object
          else
            object
          end
        end

        def deep_map(object, path = [], transform_keys:, &block)
          if object.is_a?(Hash)
            result = yield path, object

            return result if result

            object.inject({}) do |hash, (key, value)|
              key    = key.send(transform_keys)
              result = yield [*path, key], value

              hash.merge! key => (result || deep_map(value, [*path, key], transform_keys: transform_keys, &block))
            end
          elsif object.is_a?(Array)
            result = yield path, object

            return result if result

            object.map.with_index do |value, idx|
              result = yield [*path, idx], value

              result || deep_map(value, [*path, idx], transform_keys: transform_keys, &block)
            end
          else
            result = yield path, object
            result or fail Shrine::Error, "leaf reached"
          end
        end
      end
    end

    register_plugin(:versions, Versions)
  end
end
