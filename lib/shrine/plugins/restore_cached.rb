require "json"

class Shrine
  module Plugins
    # The restore_cached plugin ensures the cached file data hasn't been
    # tampered with, by restoring its metadata after assignment. The user can
    # tamper with the cached file data by modifying the hidden field before
    # submitting the form.
    #
    # Firstly the assignment is terminated if the cached file doesn't exist,
    # which can happen if the user changes the "id" or "storage" data. If the
    # cached file exists, the metadata is reextracted from the original file
    # and replaced with the potentially tampered with ones.
    #
    # plugin :restore_cached
    module RestoreCached
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

    register_plugin(:restore_cached, RestoreCached)
  end
end
