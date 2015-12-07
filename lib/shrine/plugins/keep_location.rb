class Shrine
  module Plugins
    # The keep_location plugin allows you to preserve locations when
    # transferring files from one storage to another. This can be useful for
    # debugging purposes or for backups.
    #
    #     plugin :keep_location, :cache => :store
    #
    # The above will preserve location of cached files uploaded to store. More
    # precisely, if a Shrine::UploadedFile from `:cache` is begin uploaded to
    # `:store`, the stored file will have the same location as the cached file.
    #
    # The destination storage can also be specified as an array:
    #
    #     plugin :keep_location, :cache => [:storage1, :storage2]
    module KeepLocation
      def self.configure(uploader, mappings = {})
        uploader.opts[:keep_location_mappings] = mappings
      end

      module InstanceMethods
        private

        def get_location(io, context)
          if io.is_a?(UploadedFile) && keep_location?(io) && !context[:location]
            io.id
          else
            super
          end
        end

        def keep_location?(uploaded_file)
          opts[:keep_location_mappings].any? do |source, destination|
            source == uploaded_file.storage_key.to_sym &&
              Array(destination).include?(self.storage_key)
          end
        end
      end
    end

    register_plugin(:keep_location, KeepLocation)
  end
end
