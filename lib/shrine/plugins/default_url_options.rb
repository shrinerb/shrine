# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/default_url_options.md] on GitHub.
    #
    # [doc/plugins/default_url_options.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/default_url_options.md
    module DefaultUrlOptions
      def self.configure(uploader, **options)
        uploader.opts[:default_url_options] ||= {}
        uploader.opts[:default_url_options].merge!(options)
      end

      module FileMethods
        def url(**options)
          default_options = default_url_options(options)

          super(**default_options, **options)
        end

        private

        def default_url_options(options)
          default_options = shrine_class.opts[:default_url_options][storage_key]
          default_options = default_options.call(self, options) if default_options.respond_to?(:call)
          default_options || {}
        end
      end
    end

    register_plugin(:default_url_options, DefaultUrlOptions)
  end
end
