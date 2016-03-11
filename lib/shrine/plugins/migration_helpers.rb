class Shrine
  module Plugins
    # The migration_helpers plugin gives the model additional helper methods
    # which are convenient when doing attachment migrations.
    #
    #     plugin :migration_helpers
    #
    # ## `<attachment>_cache` and `<attachment>_store`
    #
    # If your attachment's name is "avatar", the model will get `#avatar_cache`
    # and `#avatar_store` methods.
    #
    #     user = User.new
    #     user.avatar_cache #=> #<Shrine @storage_key=:cache @storage=#<Shrine::Storage::FileSystem @directory=public/uploads>>
    #     user.avatar_store #=> #<Shrine @storage_key=:store @storage=#<Shrine::Storage::S3:0x007fb8343397c8 @bucket=#<Aws::S3::Bucket name="foo">>>
    #
    # ## `<attachment>_cached?` and `<attachment>_stored?`
    #
    # You can use these methods to check whether attachment exists and is
    # cached/stored:
    #
    #     user.avatar_cached? # user.avatar && user.avatar_cache.uploaded?(user.avatar)
    #     user.avatar_stored? # user.avatar && user.avatar_store.uploaded?(user.avatar)
    #
    # ## `update_<attachment>`
    #
    # The model will also get `#update_avatar` method, which can be used when
    # doing attachment migrations. It will update the record's attachment with
    # the result of the passed in block.
    #
    #     user.update_avatar do |avatar|
    #       user.avatar_store.upload(avatar) # saved to the record
    #     end
    #
    # This will get triggered _only_ if the attachment is not nil and is
    # stored, and will get saved only if the current attachment hasn't changed
    # while executing the block. The result can be anything that responds to
    # `#to_json` and evaluates to uploaded files' data.
    module MigrationHelpers
      module AttachmentMethods
        def initialize(name)
          super

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
