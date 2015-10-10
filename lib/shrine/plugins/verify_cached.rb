require "json"

class Shrine
  module Plugins
    # The verify_cached plugin ensures the cached file data hasn't been
    # tampered with. This can happen if the user tries the modify the hidden
    # field containing the cached file data.
    #
    # It first verifies that the cached file exists, and if it doesn't
    # terminates the assignment. Afterwards it restores the metadata from the
    # underlying file, and throws away the potentially tampered metadata.
    #
    #     plugin :verify_cached
    module VerifyCached
      module AttacherMethods
        private

        def assign_cached(value)
          uploaded_file = uploaded_file(value) do |file|
            next unless cache.uploaded?(file)
            return unless file.exists?
            uploader = shrine_class.uploader_for(file)
            real_metadata = uploader.extract_metadata(file.to_io, context)
            file.metadata.update(real_metadata)
          end

          super(uploaded_file)
        end
      end
    end

    register_plugin(:verify_cached, VerifyCached)
  end
end
