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

      module AttacherMethods
        def initialize(**options)
          super(**shrine_class.opts[:default_storage], **options)
        end

        def cache_key
          if @cache.respond_to?(:call)
            @cache.call(record, name)
          else
            @cache
          end
        end

        def store_key
          if @store.respond_to?(:call)
            @store.call(record, name)
          else
            @store
          end
        end
      end
    end

    register_plugin(:default_storage, DefaultStorage)
  end
end
