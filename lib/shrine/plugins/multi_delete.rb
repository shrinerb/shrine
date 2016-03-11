class Shrine
  module Plugins
    # The multi_delete plugins allows you to leverage your storage's multi
    # delete capabilities.
    #
    #     plugin :multi_delete
    #
    # This plugin allows you pass an array of files to `Shrine#delete`.
    #
    #     Shrine.new(:storage).delete([file1, file2, file3])
    #
    # Now if you're using Storage::S3, deleting an array of files will issue a
    # single HTTP request. Some other storages may support multi deletes as
    # well. The versions plugin uses this plugin for deleting multiple versions
    # at once.
    module MultiDelete
      module InstanceMethods
        private

        # Adds the ability to upload multiple files, leveraging the underlying
        # storage's potential multi delete capability.
        def _delete(uploaded_file, context)
          if uploaded_file.is_a?(Array)
            if storage.respond_to?(:multi_delete)
              storage.multi_delete(uploaded_file.map(&:id))
            else
              uploaded_file.each { |file| _delete(file, context) }
            end
          else
            super
          end
        end
      end
    end

    register_plugin(:multi_delete, MultiDelete)
  end
end
