class Shrine
  module Plugins
    # The versions plugin enables your uploader to deal with versions. To
    # generate versions, you simply return a hash of versions in `Shrine#process`:
    #
    #     class ImageUploader < Shrine
    #       plugin :versions, names: [:large, :medium, :small]
    #
    #       def process(io, context)
    #         if context[:phase] == :store
    #           size_700 = process_to_limit!(io.download, 700, 700)
    #           size_500 = process_to_limit!(size_700,    500, 500)
    #           size_300 = process_to_limit!(size_500,    300, 300)
    #
    #           {large: size_700, medium: size_500, small: size_300}
    #         end
    #       end
    #     end
    #
    # Now when you access the attachment through the model, a hash of uploaded
    # files will be returned:
    #
    #     user.avatar #=>
    #     # {
    #     #   large:  #<Shrine::UploadedFile>,
    #     #   medium: #<Shrine::UploadedFile>,
    #     #   small:  #<Shrine::UploadedFile>,
    #     # }
    #     user.avatar.class #=> Hash
    #
    #     # With the store_dimensions plugin
    #     user.avatar[:large].width  #=> 700
    #     user.avatar[:medium].width #=> 500
    #     user.avatar[:small].width  #=> 300
    #
    # The plugin also extends the `avatar_url` method to accept versions:
    #
    #     user.avatar_url(:medium)
    #
    # This method plays nice when generating versions in a background job,
    # since it will just point to the original cached file until the versions
    # are done processing:
    #
    #     user.avatar #=> #<Shrine::UploadedFile>
    #     user.avatar_url(:medium) #=> "http://example.com/original.jpg"
    #
    #     # the versions have finished generating
    #
    #     user.avatar_url(:medium) #=> "http://example.com/medium.jpg"
    #
    # Any additional options will be properly forwarded to the underlying
    # storage:
    #
    #     user.avatar_url(:medium, download: true)
    #
    # You can also easily generate default URLs for specific versions, since
    # the `context` will include the version name:
    #
    #     class ImageUploader
    #       def default_url(io, context)
    #         "/images/defaults/#{context[:version]}.jpg"
    #       end
    #     end
    #
    # When deleting versions, any multi delete capabilities will be leveraged,
    # so when usingStorage::S3, deleting versions will issue only a single HTTP
    # request. If you want to delete versions manually, you can use
    # `Shrine.delete`:
    #
    #     versions.keys #=> [:small, :medium, :large]
    #     ImageUploader.delete(versions) # deletes a hash of versions
    module Versions
      def self.load_dependencies(uploader, *)
        uploader.plugin :multi_delete
      end

      def self.configure(uploader, names:)
        uploader.opts[:version_names] = names
      end

      module ClassMethods
        def version_names
          opts[:version_names]
        end

        # Checks that the identifier is a registered version.
        def version?(name)
          version_names.map(&:to_s).include?(name.to_s)
        end

        # Asserts that the hash doesn't contain any unknown versions.
        def versions!(hash)
          hash.select do |name, version|
            version?(name) or raise Error, "unknown version: #{name.inspect}"
          end
        end

        # Filters the hash to contain only the registered versions.
        def versions(hash)
          hash.select { |name, version| version?(name) }
        end

        # Converts a hash of data into a hash of versions.
        def uploaded_file(object, &block)
          if object.is_a?(Hash) && !object.key?("storage")
            versions(object).inject({}) do |result, (name, data)|
              result.update(name.to_sym => super(data, &block))
            end
          else
            super
          end
        end
      end

      module InstanceMethods
        # Checks whether all versions are uploaded by this uploader.
        def uploaded?(uploaded_file)
          if (hash = uploaded_file).is_a?(Hash)
            hash.all? { |name, version| super(version) }
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
            self.class.versions!(hash).inject({}) do |result, (name, version)|
              result.update(name => super(version, version: name, **context))
            end
          else
            super
          end
        end

        # Deletes each file individually, but uses S3's multi delete
        # capabilities.
        def _delete(uploaded_file, context)
          if (versions = uploaded_file).is_a?(Hash)
            super(versions.values, context)
            versions
          else
            super
          end
        end
      end

      module AttacherMethods
        # Smart versioned URLs, which include the version name in the default
        # URL, and properly forwards any options to the underlying storage.
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
      end
    end

    register_plugin(:versions, Versions)
  end
end
