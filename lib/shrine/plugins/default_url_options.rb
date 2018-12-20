# frozen_string_literal: true

class Shrine
  module Plugins
    # The `default_url_options` plugin allows you to specify URL options that
    # will be applied by default for uploaded files of specified storages.
    #
    #     plugin :default_url_options, store: { download: true }
    #
    # You can also generate the default URL options dynamically by using a
    # block, which will receive the UploadedFile object along with any options
    # that were passed to `UploadedFile#url`.
    #
    #     plugin :default_url_options, store: ->(io, **options) do
    #       { response_content_disposition: ContentDisposition.attachment(io.original_filename) }
    #     end
    #
    # In both cases the default options are merged with options passed to
    # `UploadedFile#url`, and the latter will always have precedence over
    # default options.
    module DefaultUrlOptions
      def self.configure(uploader, options = {})
        uploader.opts[:default_url_options] = (uploader.opts[:default_url_options] || {}).merge(options)
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
