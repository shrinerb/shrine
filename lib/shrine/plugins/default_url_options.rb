class Shrine
  module Plugins
    # The `default_url_options` plugin allows you to specify URL options that
    # will be applied by default for uploaded files of specified storages.
    #
    #     plugin :default_url_options, store: {download: true}
    #
    # The default options are merged with options passed to `UploadedFile#url`,
    # and the latter will always have precedence over default options.
    module DefaultUrlOptions
      def self.configure(uploader, options = {})
        uploader.opts[:default_url_options] = (uploader.opts[:default_url_options] || {}).merge(options)
      end

      module FileMethods
        def url(**options)
          super(default_options.merge(options))
        end

        private

        def default_options
          options = shrine_class.opts[:default_url_options]
          options[storage_key.to_sym] || {}
        end
      end
    end

    register_plugin(:default_url_options, DefaultUrlOptions)
  end
end
