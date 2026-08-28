# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/fallback_storage
    module FallbackStorage
      def self.configure(uploader, **opts)
        uploader.opts[:fallback_storage] ||= { store: :fallback }
        uploader.opts[:fallback_storage].merge!(opts)

        uploader.find_storage(uploader.opts.dig(:fallback_storage, :store))
      end

      module FileMethods
        def self.included(base)
          base.class_eval do
            alias_method :storage_exists?, :exists?

            def exists?
              super || fallback_storage.exists?(id)
            end
          end
        end

        def url(**)
          if storage_exists?
            super
          else
            fallback_storage.url(id, **)
          end
        end

        private

        def _open(**)
          if storage_exists?
            super
          else
            fallback_storage.open(id, **)
          end
        end

        def fallback_storage
          shrine_class.find_storage(shrine_class.opts.dig(:fallback_storage, :store))
        end
      end
    end

    register_plugin(:fallback_storage, FallbackStorage)
  end
end
