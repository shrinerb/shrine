class Shrine
  module Plugins
    # The migration_helpers plugin gives the attacher additional helper methods
    # which are convenient when doing file migrations.
    #
    # The plugin also allows convenient delegating to these methods through the
    # model, by setting `:delegate`:
    #
    #     plugin :migration_helpers, delegate: true
    #
    # ## `update_stored`
    #
    # This method updates the record's attachment with the result of the given
    # block.
    #
    #     user.avatar_attacher.update_stored do |avatar|
    #       user.avatar_attacher.store.upload(avatar) # saved to the record
    #     end
    #
    #     # with model delegation
    #     user.update_avatar do |avatar|
    #       user.avatar_store.upload(avatar) # saved to the record
    #     end
    #
    # The block will get triggered _only_ if the attachment is present and not
    # cached, *and* will save the record only if the record's attachment
    # hasn't changed in the time it took to execute the block. This method is
    # most useful for adding/removing versions and changing locations of files.
    #
    # ## `cached?` and `stored?`
    #
    # These methods return true if attachment exists and is cached/stored:
    #
    #     user.avatar_attacher.cached? # user.avatar && user.avatar_attacher.cache.uploaded?(user.avatar)
    #     user.avatar_attacher.stored? # user.avatar && user.avatar_attacher.store.uploaded?(user.avatar)
    #
    #     # with model delegation
    #     user.avatar_cached?
    #     user.avatar_stored?
    #
    # ## `attachment_cache` and `attachment_store`
    #
    # These methods return cache and store uploaders used by the underlying
    # attacher:
    #
    #     # these methods already exist without migration_helpers
    #     user.avatar_attacher.cache #=> #<Shrine @storage_key=:cache @storage=#<Shrine::Storage::FileSystem @directory=public/uploads>>
    #     user.avatar_attacher.store #=> #<Shrine @storage_key=:store @storage=#<Shrine::Storage::S3:0x007fb8343397c8 @bucket=#<Aws::S3::Bucket name="foo">>>
    #
    #     # with model delegation
    #     user.avatar_cache
    #     user.avatar_store
    module MigrationHelpers
      def self.configure(uploader, delegate: false)
        uploader.opts[:migration_helpers_delegate] = delegate
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
