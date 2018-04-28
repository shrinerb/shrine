# frozen_string_literal: true

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
    #     require "image_processing/mini_magick"
    #
    #     plugin :processing
    #
    #     process(:store) do |io, context|
    #       original = io.download
    #       pipeline = ImageProcessing::MiniMagick.source(original)
    #
    #       size_800 = pipeline.resize_to_limit!(800, 800)
    #       size_500 = pipeline.resize_to_limit!(500, 500)
    #       size_300 = pipeline.resize_to_limit!(300, 300)
    #
    #       original.close!
    #
    #       { original: io, large: size_800, medium: size_500, small: size_300}
    #     end
    #
    # You probably want to load the `delete_raw` plugin to automatically
    # delete processed files after they have been uploaded.
    #
    # Now when you access the stored attachment through the model, a hash of
    # uploaded files will be returned:
    #
    #     user.avatar_data #=>
    #     # '{
    #     #   "original": {"id":"0gsdf.jpg", "storage":"store", "metadata":{...}},
    #     #   "large": {"id":"lg043.jpg", "storage":"store", "metadata":{...}},
    #     #   "medium": {"id":"kd9fk.jpg", "storage":"store", "metadata":{...}},
    #     #   "small": {"id":"932fl.jpg", "storage":"store", "metadata":{...}}
    #     # }'
    #
    #     user.avatar #=>
    #     # {
    #     #   :original => #<Shrine::UploadedFile @data={"id"=>"0gsdf.jpg", ...}>,
    #     #   :large    => #<Shrine::UploadedFile @data={"id"=>"lg043.jpg", ...}>,
    #     #   :medium   => #<Shrine::UploadedFile @data={"id"=>"kd9fk.jpg", ...}>,
    #     #   :small    => #<Shrine::UploadedFile @data={"id"=>"932fl.jpg", ...}>,
    #     # }
    #
    #     user.avatar[:medium]     #=> #<Shrine::UploadedFile>
    #     user.avatar[:medium].url #=> "/uploads/store/lg043.jpg"
    #
    # The plugin also extends the `Attacher#url` to accept versions:
    #
    #     user.avatar_url(:large)
    #     user.avatar_url(:small, download: true) # with URL options
    #
    # `Shrine.uploaded_file` will also instantiate a hash of
    # `Shrine::UploadedFile` objects if given data with versions. If you want
    # to apply a change to all files in an attachment, regardless of whether
    # it consists of a single file or a hash of versions, you can pass a block
    # to `Shrine.uploaded_file` and it will yield each file:
    #
    #     Shrine.uploaded_file(attachment_data) do |uploaded_file|
    #       # ...
    #     end
    #
    # ## Fallbacks
    #
    # If versions are processed in a background job, there will be a period
    # where the user will browse the site before versions have finished
    # processing. In this period `Attacher#url` will by default fall back to
    # the original file.
    #
    #     user.avatar #=> #<Shrine::UploadedFile>
    #     user.avatar_url(:large) # falls back to `user.avatar_url`
    #
    # This behaviour is convenient if you want to gracefully degrade to the
    # cached file until the background job has finished processing. However, if
    # you would rather provide your own default URLs for versions, you can
    # disable this fallback:
    #
    #     plugin :versions, fallback_to_original: false
    #
    # If you already have some versions processed in the foreground after a
    # background job is kicked off (with the `recache` plugin), you can have
    # URLs for versions that are yet to be processed fall back to existing
    # versions:
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
    # ## Arrays
    #
    # In addition to Hashes, the plugin also supports Arrays of files. For
    # example, you might want to split a PDf into pages:
    #
    #     process(:store) do |io, context|
    #       pdf        = io.download
    #       page_count = MiniMagick::Image.new(pdf.path).pages.count
    #       pipeline   = ImageProcessing::MiniMagick.source(pdf).convert("jpg")
    #
    #       pages = page_count.times.map do |page_number|
    #         pipeline.loader(page: page_number).call
    #       end
    #
    #       pdf.close!
    #
    #       { pages: pages } # array of pages
    #     end
    #
    # You can also combine Hashes and Arrays, there is no limit to the level of
    # nesting.
    #
    # ## Original file
    #
    # It's recommended to always keep the original file after processing
    # versions, which you can do by adding the yielded `Shrine::UploadedFile`
    # object as one of the versions, by convention named `:original`:
    #
    #     process(:store) do |io, context|
    #       # processing thumbnail
    #       { original: io, thumbnail: thumbnail }
    #     end
    #
    # If both temporary and permanent storage are Amazon S3, the cached original
    # will simply be copied over to permanent storage (without any downloading
    # and reuploading), so in these cases the performance impact of storing the
    # original file in addition to processed versions is neglibible.
    #
    # ## Context
    #
    # The version name will be available via `:version` when generating
    # location or a default URL.
    #
    #     def generate_location(io, context)
    #       "uploads/#{context[:version]}-#{super}"
    #     end
    #
    #     Attacher.default_url do |options|
    #       "/images/defaults/#{options[:version]}.jpg"
    #     end
    #
    # ## Re-create Versions
    #
    # If you want to re-create a single or all versions, refer to the [reprocessing versions] guide for details.
    #
    # [reprocessing versions]: https://shrinerb.com/rdoc/files/doc/regenerating_versions_md.html
    # [image_processing]: https://github.com/janko-m/image_processing
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
              result.merge!(name => _store(value, context.merge(version: name){|_, v1, v2| Array(v1) + Array(v2)}))
            end
          elsif (array = io).is_a?(Array)
            array.map.with_index { |value, idx| _store(value, context.merge(version: idx){|_, v1, v2| Array(v1) + Array(v2)}) }
          else
            super
          end
        end

        # Deletes each file individually, but uses S3's multi delete
        # capabilities.
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

        def assign_cached(value)
          cached_file = uploaded_file(value)
          Shrine.deprecation("Assigning cached hash of files is deprecated for security reasons and will be removed in Shrine 3.") if cached_file.is_a?(Hash) || cached_file.is_a?(Array)
          super(cached_file)
        end

        # Converts the Hash of UploadedFile objects into a Hash of data.
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
