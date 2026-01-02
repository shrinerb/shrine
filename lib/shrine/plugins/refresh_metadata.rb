# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/refresh_metadata
    module RefreshMetadata
      module AttacherMethods
        def refresh_metadata!(**)
          file!.refresh_metadata!(**context, **)
          set(file) # trigger model write
        end
      end

      module FileMethods
        def refresh_metadata!(replace: false, **)
          return open { refresh_metadata!(replace:, **) } unless opened?

          refreshed_metadata = uploader.send(:get_metadata, self, metadata: true, **)

          @metadata = replace ? refreshed_metadata : @metadata.merge(refreshed_metadata)
        end
      end
    end

    register_plugin(:refresh_metadata, RefreshMetadata)
  end
end
