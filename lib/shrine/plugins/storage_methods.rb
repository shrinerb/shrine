class Shrine
  module Plugins
    # The storage_methods plugin gives convenient reader methods for accessing
    # the cache and store of an attachment.
    #
    #     plugin :storage_methods
    #
    # If your attachment's name is "avatar", the model will get `#avatar_cache`
    # and `#avatar_store` methods.
    #
    #     user = User.new
    #     user.avatar_cache #=> #<Shrine @storage_key=:cache @storage=#<Shrine::Storage::FileSystem @directory=public/uploads>>
    #     user.avatar_store #=> #<Shrine @storage_key=:store @storage=#<Shrine::Storage::S3:0x007fb8343397c8 @bucket=#<Aws::S3::Bucket name="foo">>>
    module StorageMethods
      module AttachmentMethods
        def initialize(name)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}_cache
              #{name}_attacher.cache
            end

            def #{name}_store
              #{name}_attacher.store
            end
          RUBY
        end
      end
    end

    register_plugin(:storage_methods, StorageMethods)
  end
end
