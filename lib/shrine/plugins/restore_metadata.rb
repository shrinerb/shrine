require "json"

class Shrine
  module Plugins
    module RestoreMetadata
      module AttacherMethods
        private

        def retrieve(value)
          super do |file|
            uploader = shrine_class.uploader_for(file)
            real_metadata = uploader.extract_metadata(file.to_io, context)
            file.metadata.update(real_metadata)
          end
        end
      end
    end

    register_plugin(:restore_metadata, RestoreMetadata)
  end
end
