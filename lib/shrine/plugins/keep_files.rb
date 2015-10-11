class Shrine
  module Plugins
    # The keep_files plugin gives you the ability to prevent files from being
    # deleted.
    #
    #     plugin :keep_files
    #
    # This functionality is useful when implementing soft deletes, or when
    # implementing some kind of [event store] where you need to track history.
    # The plugin accepts the following options:
    #
    # :destroyed
    # :  If set to `true`, destroying the record won't delete the associated
    #    attachment.
    #
    # :replaced
    # :  If set to `true`, uploading a new attachment won't delete the old one.
    #
    # :cached
    # :  If set to `true`, cached files that are uploaded to store won't be
    #    deleted.
    #
    # [event store]: http://docs.geteventstore.com/introduction/event-sourcing-basics/
    module KeepFiles
      def self.configure(uploader, destroyed: nil, replaced: nil, cached: nil)
        uploader.opts[:keep_files] = []
        uploader.opts[:keep_files] << :destroyed if destroyed
        uploader.opts[:keep_files] << :replaced if replaced
        uploader.opts[:keep_files] << :cached if cached
      end

      module ClassMethods
        def keep?(type)
          opts[:keep_files].include?(type)
        end

        # We hook to the generic deleting, and check the appropriate phases.
        def delete(io, context)
          case context[:phase]
          when :promote then super unless keep?(:cached)
          when :replace then super unless keep?(:replaced)
          when :destroy then super unless keep?(:destroyed)
          else
            super
          end
        end
      end
    end

    register_plugin(:keep_files, KeepFiles)
  end
end
