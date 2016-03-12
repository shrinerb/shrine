class Shrine
  module Plugins
    # The keep_files plugin gives you the ability to prevent files from being
    # deleted. This functionality is useful when implementing soft deletes, or
    # when implementing some kind of [event store] where you need to track
    # history.
    #
    # The plugin accepts the following options:
    #
    # :destroyed
    # :  If set to `true`, destroying the record won't delete the associated
    #    attachment.
    #
    # :replaced
    # :  If set to `true`, uploading a new attachment won't delete the old one.
    #
    # For example, the following will keep destroyed and replaced files:
    #
    #     plugin :keep_files, destroyed: true, :replaced: true
    #
    # [event store]: http://docs.geteventstore.com/introduction/event-sourcing-basics/
    module KeepFiles
      def self.configure(uploader, destroyed: nil, replaced: nil, **)
        uploader.opts[:keep_files] = []
        uploader.opts[:keep_files] << :destroyed if destroyed
        uploader.opts[:keep_files] << :replaced if replaced
      end

      module AttacherMethods
        def replace
          super unless shrine_class.opts[:keep_files].include?(:replaced)
        end

        def destroy
          super unless shrine_class.opts[:keep_files].include?(:destroyed)
        end
      end
    end

    register_plugin(:keep_files, KeepFiles)
  end
end
