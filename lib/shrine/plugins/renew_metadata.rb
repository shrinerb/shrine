require "json"

class Shrine
  module Plugins
    module RenewMetadata
      module AttacherMethods
        def set(value)
          if value.is_a?(Hash) || value.is_a?(String) && !value.empty?
            uploaded_file = shrine_class.uploaded_file(value) do |file|
              uploader = shrine_class.uploader_for(file)
              real_metadata = uploader.extract_metadata(file.to_io, context)
              file.metadata.update(real_metadata)
            end

            super uploaded_file.to_json
          else
            super
          end
        end
      end
    end

    register_plugin(:renew_metadata, RenewMetadata)
  end
end
