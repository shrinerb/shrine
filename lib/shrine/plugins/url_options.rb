# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/url_options.md] on GitHub.
    #
    # [doc/plugins/url_options.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/url_options.md
    module UrlOptions
      def self.configure(uploader, **options)
        uploader.opts[:url_options] ||= {}
        uploader.opts[:url_options].merge!(options)
      end

      module FileMethods
        def url(**options)
          default_options = url_options(options)

          super(**default_options, **options)
        end

        private

        def url_options(options)
          default_options = shrine_class.opts[:url_options][storage_key]
          default_options = default_options.call(self, options) if default_options.respond_to?(:call)
          default_options || {}
        end
      end
    end

    register_plugin(:url_options, UrlOptions)
  end
end
