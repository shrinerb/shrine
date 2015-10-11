class Shrine
  module Plugins
    # The moving plugin enables you to move files to specified storages. On
    # the filesystem moving is istantaneous, since the OS only changes the
    # pointer, so this plugin is useful when dealing with large files.
    #
    # This plugin is also recommended if you're doing processing, since by
    # default temporary files won't immediately get deleted (Ruby's Tempfiles
    # usually get deleted only when the process ends).
    #
    #     plugin :moving, storages: [:cache]
    #
    # The `:storages` option specifies which storages the file will be moved
    # to. The above will move Rails's uploaded files to cache (without this
    # plugin it's simply copied over). However, you may want to move cached
    # files to `:store` as well:
    #
    #     plugin :moving, storages: [:cache, :store]
    #
    # What exactly means "moving"? Usually this means that the file which is
    # being uploaded will be deleted afterwards. However, if both the file
    # being uploaded and the destination are on the filesystem, a `mv` command
    # will be executed instead. Some other storages may implement moving as
    # well, usually if also both the `:cache` and `:store` are using the same
    # storage.
    module Moving
      def self.configure(uploader, storages:)
        uploader.opts[:move_files_to_storages] = storages
      end

      module InstanceMethods
        private

        # If the file is movable (usually this means that both the file and
        # the destination are on the filesystem), use the underlying storage's
        # ability to move. Otherwise we "imitate" moving by deleting the file
        # after it was uploaded.
        def put(io, context)
          if move?(io, context)
            if movable?(io, context)
              move(io, context)
            else
              super
              io.delete if io.respond_to?(:delete)
            end
            # Promoting cached files will by default always delete the cached
            # file. But, if moving plugin is enabled we want the cached file to
            # be moved instead. However, there is no good way of letting the
            # Attacher know that it shouldn't attempt to delete the file, so we
            # make this instance variable hack.
            io.instance_variable_set("@shrine_deleted", true)
          else
            super
          end
        end

        # Don't delete the file if it has been moved.
        def remove(io, context)
          super unless io.instance_variable_get("@shrine_deleted")
        end

        # Ask the storage if the given file is movable.
        def movable?(io, context)
          storage.respond_to?(:move) && storage.movable?(io, context[:location])
        end

        def move?(io, context)
          opts[:move_files_to_storages].include?(storage_key)
        end
      end
    end

    register_plugin(:moving, Moving)
  end
end
