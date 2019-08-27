# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/default_storage.md] on GitHub.
    #
    # [doc/plugins/default_storage.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/default_storage.md
    module DefaultStorage
      def self.configure(uploader, **opts)
        uploader.opts[:default_storage] ||= {}
        uploader.opts[:default_storage].merge!(opts)
      end

      module AttacherClassMethods
        def default_cache(value = nil, &block)
          default_storage.merge!(cache: value || block)
        end

        def default_store(value = nil, &block)
          default_storage.merge!(store: value || block)
        end

        private

        def default_storage
          shrine_class.opts[:default_storage]
        end
      end

      module AttacherMethods
        def initialize(**options)
          super(**shrine_class.opts[:default_storage], **options)
        end

        def cache_key
          if @cache.respond_to?(:call)
            if @cache.arity == 2
              Shrine.deprecation("Passing record & name argument to default storage block is deprecated and will be removed in Shrine 4. Use a block without arguments instead.")
              @cache.call(record, name)
            else
              instance_exec(&@cache)
            end
          else
            @cache
          end
        end

        def store_key
          if @store.respond_to?(:call)
            if @store.arity == 2
              Shrine.deprecation("Passing record & name argument to default storage block is deprecated and will be removed in Shrine 4. Use a block without arguments instead.")
              @store.call(record, name)
            else
              instance_exec(&@store)
            end
          else
            @store
          end
        end
      end
    end

    register_plugin(:default_storage, DefaultStorage)
  end
end
