# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/multi_cache
    module MultiCache
      def self.configure(uploader, **opts)
        uploader.opts[:multi_cache] ||= {}
        uploader.opts[:multi_cache].merge!(opts)
      end

      module AttacherMethods
        def cached?(file = self.file)
          super || additional_cache.any? { |key| uploaded?(file, key) }
        end

        private

        def additional_cache
          Array(shrine_class.opts[:multi_cache][:additional_cache])
        end
      end
    end

    register_plugin(:multi_cache, MultiCache)
  end
end
