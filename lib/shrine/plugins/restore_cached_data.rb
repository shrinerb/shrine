# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/restore_cached_data.md] on GitHub.
    #
    # [doc/plugins/restore_cached_data.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/restore_cached_data.md
    module RestoreCachedData
      def self.load_dependencies(uploader, *)
        uploader.plugin :refresh_metadata
      end

      module AttacherMethods
        private

        def cached(value)
          cached_file = super

          # TODO: Remove this conditional when we remove the versions plugin
          if cached_file.is_a?(Hash) || cached_file.is_a?(Array)
            uploaded_file(cached_file) { |file| file.refresh_metadata!(context) }
          else
            cached_file.refresh_metadata!(context)
          end

          cached_file
        end
      end
    end

    register_plugin(:restore_cached_data, RestoreCachedData)
  end
end
