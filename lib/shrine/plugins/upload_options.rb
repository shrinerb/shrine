class Shrine
  module Plugins
    # The upload_options allows you to automatically pass additional upload
    # options to storage on every upload:
    #
    #     plugin :upload_options, cache: {acl: "private"}
    #
    # Keys are names of the registered storages, and values are either hashes
    # or blocks.
    #
    #     plugin :upload_options, store: ->(io, context) do
    #       if [:original, :thumb].include?(context[:version])
    #         {acl: "public-read"}
    #       else
    #         {acl: "private"}
    #       end
    #     end
    module UploadOptions
      def self.configure(uploader, options = {})
        uploader.opts[:upload_options] = options
      end

      module InstanceMethods
        def put(io, context)
          upload_options = get_upload_options(io, context)
          key = storage.class.name.split("::").last.downcase
          context[:metadata][key] = upload_options if upload_options
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
