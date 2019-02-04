# frozen_string_literal: true

class Shrine
  module Plugins
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
