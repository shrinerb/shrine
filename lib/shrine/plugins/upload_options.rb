# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/upload_options.md] on GitHub.
    #
    # [doc/plugins/upload_options.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/upload_options.md
    module UploadOptions
      def self.configure(uploader, options = {})
        uploader.opts[:upload_options] ||= {}
        uploader.opts[:upload_options].merge!(options)
      end

      module InstanceMethods
        private

        def _upload(io, **options)
          upload_options = get_upload_options(io, options)

          super(io, **options, upload_options: upload_options)
        end

        def get_upload_options(io, options)
          upload_options = opts[:upload_options][storage_key] || {}
          upload_options = upload_options.call(io, options) if upload_options.respond_to?(:call)
          upload_options = upload_options.merge(options[:upload_options]) if options[:upload_options]
          upload_options
        end
      end
    end

    register_plugin(:upload_options, UploadOptions)
  end
end
