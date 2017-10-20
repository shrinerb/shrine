# frozen_string_literal: true

class Shrine
  module Plugins
    # The `default_storage` plugin enables you to change which storages are going
    # to be used for this uploader's attacher (the default is `:cache` and
    # `:store`).
    #
    #     plugin :default_storage, cache: :special_cache, store: :special_store
    #
    # You can also pass a block and choose the values depending on the record
    # values and the name of the attachment. This is useful if you're using the
    # `dynamic_storage` plugin. Example:
    #
    #     plugin :default_storage, store: ->(record, name) { :"store_#{record.username}" }
    module DefaultStorage
      def self.configure(uploader, opts = {})
        uploader.opts[:default_storage_cache] = opts.fetch(:cache, uploader.opts[:default_storage_cache])
        uploader.opts[:default_storage_store] = opts.fetch(:store, uploader.opts[:default_storage_store])
      end

      module AttacherMethods
        def initialize(record, name, **options)
          if cache = shrine_class.opts[:default_storage_cache]
            cache = cache.call(record, name) if cache.respond_to?(:call)
            options[:cache] = cache
          end

          if store = shrine_class.opts[:default_storage_store]
            store = store.call(record, name) if store.respond_to?(:call)
            options[:store] = store
          end

          super
        end
      end
    end

    register_plugin(:default_storage, DefaultStorage)
  end
end
