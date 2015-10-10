require "json"

class Shrine
  module Plugins
    module RestoreMetadata
      module AttacherMethods
        private

        def assign_cached(value)
          uploaded_file = uploaded_file(value) do |file|
            next unless cache.uploaded?(file)
            uploader = shrine_class.uploader_for(file)
            real_metadata = uploader.extract_metadata(file.to_io, context)
            file.metadata.update(real_metadata)
          end

          super(uploaded_file)
        end
      end
    end

    register_plugin(:restore_metadata, RestoreMetadata)
  end
end
