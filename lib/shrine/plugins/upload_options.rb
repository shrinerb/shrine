# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/upload_options
    module UploadOptions
      def self.configure(uploader, **opts)
        uploader.opts[:upload_options] ||= {}
        uploader.opts[:upload_options].merge!(opts)
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
