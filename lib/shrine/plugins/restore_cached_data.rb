# frozen_string_literal: true

class Shrine
  module Plugins
    # The `restore_cached_data` plugin re-extracts metadata when assigning
    # already cached files, i.e. when the attachment has been retained on
    # validation errors or assigned from a direct upload. In both cases you may
    # want to re-extract metadata on the server side, mainly to prevent
    # tempering, but also in case of direct uploads to obtain metadata that
    # couldn't be extracted on the client side.
    #
    #     plugin :restore_cached_data
    #
    # It uses the `refresh_metadata` plugin to re-extract metadata.
    module RestoreCachedData
      def self.load_dependencies(uploader, *)
        uploader.plugin :refresh_metadata
      end

      module AttacherMethods
        private

        def assign_cached(cached_file)
          uploaded_file(cached_file) { |file| file.refresh_metadata!(context) }
          super(cached_file)
        end
      end
    end

    register_plugin(:restore_cached_data, RestoreCachedData)
  end
end
