# frozen_string_literal: true

class Shrine
  module Plugins
    module DefaultUrlOptions
      def self.configure(uploader, options = {})
        uploader.opts[:default_url_options] ||= {}
        uploader.opts[:default_url_options].merge!(options)
      end

      module FileMethods
        def url(**options)
          default_options   = default_url_options
          default_options   = default_options.call(self, **options) if default_options.respond_to?(:call)
          default_options ||= {}

          super(default_options.merge(options))
        end

        private

        def default_url_options
          options = shrine_class.opts[:default_url_options]
          options[storage_key.to_sym]
        end
      end
    end

    register_plugin(:default_url_options, DefaultUrlOptions)
  end
end
