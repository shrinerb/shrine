class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/multi_cache.md] on GitHub.
    #
    # [doc/plugins/multi_cache.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/multi_cache.md
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
