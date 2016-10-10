class Shrine
  module Plugins
    # The `versions` plugin enables your uploader to deal with versions, by
    # allowing you to return a Hash of files when processing.
    #
    #     plugin :versions
    #
    # Here is an example of processing image thumbnails using the
    # [image_processing] gem:
    #
    #     include ImageProcessing::MiniMagick
    #     plugin :processing
    #
    #     process(:store) do |io, context|
    #       size_700 = resize_to_limit(io.download, 700, 700)
    #       size_500 = resize_to_limit(size_700,    500, 500)
    #       size_300 = resize_to_limit(size_500,    300, 300)
    #
    #       {large: size_700, medium: size_500, small: size_300}
    #     end
    #
    # Now when you access the stored attachment through the model, a hash of
    # uploaded files will be returned:
    #
    #     JSON.parse(user.avatar_data) #=>
    #     # {
    #     #   "large"  => {"id" => "lg043.jpg", "storage" => "store", "metadata" => {...}},
    #     #   "medium" => {"id" => "kd9fk.jpg", "storage" => "store", "metadata" => {...}},
    #     #   "small"  => {"id" => "932fl.jpg", "storage" => "store", "metadata" => {...}},
    #     # }
    #
    #     user.avatar #=>
    #     # {
    #     #   :large =>  #<Shrine::UploadedFile @data={"id"=>"lg043.jpg", ...}>,
    #     #   :medium => #<Shrine::UploadedFile @data={"id"=>"kd9fk.jpg", ...}>,
    #     #   :small =>  #<Shrine::UploadedFile @data={"id"=>"932fl.jpg", ...}>,
    #     # }
    #
    #     # With the store_dimensions plugin
    #     user.avatar[:large].width  #=> 700
    #     user.avatar[:medium].width #=> 500
    #     user.avatar[:small].width  #=> 300
    #
    # You probably want to load the `delete_raw` plugin to automatically
    # delete processed files after they have been uploaded.
    #
    # ## Original file
    #
    # If you want to keep the original file, you can forward it as is without
    # explicitly downloading it (since `Shrine::UploadedFile` itself is an
    # IO-like object), which might avoid downloading depending on the storage:
    #
    #     process(:store) do |io, context|
    #       # processing thumbnail
    #       {original: io, thumbnail: thumbnail}
    #     end
    #
    # ## Fallbacks
    #
    # The plugin also extends the `<attachmen>_url` method to accept versions,
    # and adds automatic fallbacks:
    #
    #     user.avatar_url(:medium)
    #
    #     # returns URL of that version if versions have been created,
    #     # otherwise returns original URL if attachment exists,
    #     # otherwise returns nil
    #
    # This behaviour is convenient when using background jobs, as it allows you
    # to gracefully degrade before the background job finishes.
    #
    # If you already have some versions processed in the foreground when a
    # background job is kicked off (with the `recache` plugin), the
    # `<attachment>_url` method won't know which version to use as a fallback.
    # In that case you can specify `:fallbacks` when loading the plugin:
    #
    #     plugin :versions, fallbacks: {
    #       :thumb_2x => :thumb,
    #       :large_2x => :large,
    #     }
    #
    #     # ... (background job is kicked off)
    #
    #     user.avatar_url(:thumb_2x) # returns :thumb URL until :thumb_2x becomes available
    #     user.avatar_url(:large_2x) # returns :large URL until :large_2x becomes available
    #
    # Any additional options will be properly forwarded to the underlying
    # storage:
    #
    #     user.avatar_url(:medium, download: true)
    #
    # ## Context
    #
    # The `context` will now also include the version name, which you can use
    # when generating a location or a default URL:
    #
    #     def generate_location(io, context)
    #       "uploads/#{context[:version]}-#{super}"
    #     end
    #
    #     plugin :default_url do |context|
    #       "/images/defaults/#{context[:version]}.jpg"
    #     end
    #
    # [image_processing]: https://github.com/janko-m/image_processing
    module Versions
      def self.load_dependencies(uploader, *)
        uploader.plugin :multi_delete
        uploader.plugin :default_url
      end

      def self.configure(uploader, opts = {})
        warn "The versions Shrine plugin doesn't need the :names option anymore, you can safely remove it." if opts.key?(:names)

        uploader.opts[:version_names] = opts.fetch(:names, uploader.opts[:version_names])
        uploader.opts[:version_fallbacks] = opts.fetch(:fallbacks, uploader.opts.fetch(:version_fallbacks, {}))
      end

      module ClassMethods
        def version_names
          warn "Shrine.version_names is deprecated and will be removed in Shrine 3."
          opts[:version_names]
        end

        def version_fallbacks
          opts[:version_fallbacks]
        end

        # Checks that the identifier is a registered version.
        def version?(name)
          warn "Shrine.version? is deprecated and will be removed in Shrine 3."
          version_names.nil? || version_names.map(&:to_s).include?(name.to_s)
        end

        # Converts a hash of data into a hash of versions.
        def uploaded_file(object, &block)
          if (hash = object).is_a?(Hash) && !hash.key?("storage")
            hash.inject({}) do |result, (name, data)|
              result.update(name.to_sym => uploaded_file(data, &block))
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
            hash.all? { |name, version| uploaded?(version) }
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
            hash.inject({}) do |result, (name, version)|
              result.update(name => _store(version, version: name, **context))
            end
          else
            super
          end
        end

        # Deletes each file individually, but uses S3's multi delete
        # capabilities.
        def _delete(uploaded_file, context)
          if (versions = uploaded_file).is_a?(Hash)
            _delete(versions.values, context)
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
              if file = get[version]
                file.url(**options)
              elsif fallback = shrine_class.version_fallbacks[version]
                url(fallback, **options)
              else
                default_url(**options, version: version)
              end
            else
              raise Error, "must call #{name}_url with the name of the version"
            end
          else
            if get || version.nil?
              super(**options)
            else
              default_url(**options, version: version)
            end
          end
        end

        private

        def assign_cached(value)
          cached_file = uploaded_file(value)
          warn "Assigning cached hash of files is deprecated for security reasons and will be removed in Shrine 3." if cached_file.is_a?(Hash)
          super(cached_file)
        end

        # Converts the Hash of UploadedFile objects into a Hash of data.
        def convert_to_data(value)
          if value.is_a?(Hash)
            value.inject({}) do |hash, (name, uploaded_file)|
              hash.merge!(name => super(uploaded_file))
            end
          else
            super
          end
        end
      end
    end

    register_plugin(:versions, Versions)
  end
end
