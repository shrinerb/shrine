# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/default_storage.md] on GitHub.
    #
    # [doc/plugins/default_storage.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/default_storage.md
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
