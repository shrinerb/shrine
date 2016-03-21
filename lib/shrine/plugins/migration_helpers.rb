class Shrine
  module Plugins
    # The migration_helpers plugin gives the attacher additional helper methods
    # which are convenient when doing file migrations.
    #
    # By default additional methods are also added to the model which delegate
    # to the underlying attacher. If you want to disable that, you can load the
    # plugin with `delegate: false`:
    #
    #     plugin :migration_helpers, delegate: false
    #
    # ## `attachment_cache` and `attachment_store`
    #
    # These methods return cache and store uploaders used by the underlying
    # attacher:
    #
    #     user.avatar_cache #=> #<Shrine @storage_key=:cache @storage=#<Shrine::Storage::FileSystem @directory=public/uploads>>
    #     user.avatar_store #=> #<Shrine @storage_key=:store @storage=#<Shrine::Storage::S3:0x007fb8343397c8 @bucket=#<Aws::S3::Bucket name="foo">>>
    #
    #     # attacher equivalents
    #     user.avatar_attacher.cache
    #     user.avatar_attacher.store
    #
    # ## `attachment_cached?` and `attachment_stored?`
    #
    # These methods return true if attachment exists and is cached/stored:
    #
    #     user.avatar_cached? # user.avatar && user.avatar_cache.uploaded?(user.avatar)
    #     user.avatar_stored? # user.avatar && user.avatar_store.uploaded?(user.avatar)
    #
    #     # attacher equivalents
    #     user.avatar_attacher.cached?
    #     user.avatar_attacher.stored?
    #
    # ## `update_attachment`
    #
    # This method updates the record's attachment with the result of the given
    # block.
    #
    #     user.update_avatar do |avatar|
    #       user.avatar_store.upload(avatar) # saved to the record
    #     end
    #
    #     # attacher equivalent
    #     user.avatar_attacher.update_stored { |avatar| }
    #
    # The block will get triggered _only_ if the attachment is present and not
    # cached, *and* will save the record only if the record's attachment
    # hasn't changed in the time it took to execute the block. This method is
    # most useful for adding/removing versions and changing locations of files.
    module MigrationHelpers
      def self.configure(uploader, options = {})
        warn "The :delegate option in migration_helpers Shrine plugin will default to false in Shrine 2. To remove this warning, set :delegate explicitly." if !options.key?(:delegate)
        uploader.opts[:migration_helpers_delegate] = options.fetch(:delegate, true)
      end

      module AttachmentMethods
        def initialize(name)
          super

          return if shrine_class.opts[:migration_helpers_delegate] == false

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def update_#{name}(&block)
              #{name}_attacher.update_stored(&block)
            end

            def #{name}_cache
              #{name}_attacher.cache
            end

            def #{name}_store
              #{name}_attacher.store
            end

            def #{name}_cached?
              #{name}_attacher.cached?
            end

            def #{name}_stored?
              #{name}_attacher.stored?
            end
          RUBY
        end
      end

      module AttacherMethods
        # Updates the attachment with the result of the block. It will get
        # called only if the attachment exists and is stored.
        def update_stored(&block)
          return if get.nil? || cache.uploaded?(get)
          new_attachment = block.call(get)
          swap(new_attachment)
        end

        # Returns true if the attachment is present and is uploaded by the
        # temporary storage.
        def cached?
          get && cache.uploaded?(get)
        end

        # Returns true if the attachment is present and is uploaded by the
        # permanent storage.
        def stored?
          get && store.uploaded?(get)
        end
      end
    end

    register_plugin(:migration_helpers, MigrationHelpers)
  end
end
