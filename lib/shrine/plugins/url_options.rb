# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/url_options
    module UrlOptions
      def self.configure(uploader, options = {})
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
          default_options = find_url_options
          default_options = default_options.call(self, options) if default_options.respond_to?(:call)
          default_options || {}
        end

        # Matches the storage key exactly first, then falls back to any
        # registered regex that matches the storage key. The regex form is
        # useful when storage keys are generated dynamically (e.g. via the
        # `dynamic_storage` plugin), since it's not possible to list every
        # storage key upfront.
        def find_url_options
          url_options = shrine_class.opts[:url_options]

          return url_options[storage_key] if url_options.key?(storage_key)

          _, options = url_options.find { |key, _| key.is_a?(Regexp) && key.match?(storage_key.to_s) }
          options
        end
      end
    end

    register_plugin(:url_options, UrlOptions)
  end
end
