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
        def put(io, context)
          upload_options = get_upload_options(io, context)
          context = { upload_options: upload_options }.merge(context)
          super
        end

        private

        def get_upload_options(io, context)
          options = opts[:upload_options][storage_key]
          options = options.call(io, context) if options.respond_to?(:call)
          options
        end
      end
    end

    register_plugin(:upload_options, UploadOptions)
  end
end
