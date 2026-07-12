# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/upload_options
    module UploadOptions
      def self.configure(uploader, options = {})
        uploader.opts[:upload_options] ||= {}
        uploader.opts[:upload_options].merge!(options)
      end

      module InstanceMethods
        private

        def _upload(io, **options)
          upload_options = get_upload_options(io, options)

          super(io, **options, upload_options:)
        end

        def get_upload_options(io, options)
          upload_options = find_upload_options || {}
          upload_options = upload_options.call(io, options) if upload_options.respond_to?(:call)
          upload_options = upload_options.merge(options[:upload_options]) if options[:upload_options]
          upload_options
        end

        # Matches the storage key exactly first, then falls back to any
        # registered regex that matches the storage key. The regex form is
        # useful when storage keys are generated dynamically (e.g. via the
        # `dynamic_storage` plugin), since it's not possible to list every
        # storage key upfront.
        def find_upload_options
          upload_options = opts[:upload_options]

          return upload_options[storage_key] if upload_options.key?(storage_key)

          _, options = upload_options.find { |key, _| key.is_a?(Regexp) && key.match?(storage_key.to_s) }
          options
        end
      end
    end

    register_plugin(:upload_options, UploadOptions)
  end
end
