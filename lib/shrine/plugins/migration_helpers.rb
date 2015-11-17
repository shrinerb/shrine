class Shrine
  module Plugins
    # The migration_helpers plugin gives the model additional helper methods
    # which are convenient when doing attachment migrations.
    #
    #     plugin :migration_helpers
    #
    # If your attachment's name is "avatar", the model will get `#avatar_cache`
    # and `#avatar_store` methods.
    #
    #     user = User.new
    #     user.avatar_cache #=> #<Shrine @storage_key=:cache @storage=#<Shrine::Storage::FileSystem @directory=public/uploads>>
    #     user.avatar_store #=> #<Shrine @storage_key=:store @storage=#<Shrine::Storage::S3:0x007fb8343397c8 @bucket=#<Aws::S3::Bucket name="foo">>>
    #
    # The model will also get `#update_avatar` method, which should be used
    # when doing attachment migrations. It will update the record's attachment
    # with the result of the passed in block.
    #
    #     user.update_avatar do |avatar|
    #       user.avatar_store.upload(avatar) # saved to the record
    #     end
    #
    # This will get triggered _only_ if the attachment exists and is stored.
    # The result can be anything that responds to `#to_json` and evaluates to
    # uploaded files' data.
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
          RUBY
        end
      end

      module AttacherMethods
        # Updates the attachment with the result of the block. It will get
        # called only if the attachment exists and is stored.
        def update_stored(&block)
          attachment = get
          return if attachment.nil? || cache.uploaded?(attachment)
          new_attachment = block.call(attachment)
          update(new_attachment) unless changed?(attachment)
        end
      end
    end

    register_plugin(:migration_helpers, MigrationHelpers)
  end
end
