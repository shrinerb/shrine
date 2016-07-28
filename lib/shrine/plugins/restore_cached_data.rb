class Shrine
  module Plugins
    # The restore_cached_data plugin ensures the cached file metadata hasn't
    # been tampered with, which can be done by modifying the hidden field
    # before submitting the form. The cached file's metadata will be
    # reextracted during assignment and replaced with potentially tampered one.
    #
    #     plugin :restore_cached_data
    module RestoreCachedData
      module AttacherMethods
        private

        def assign_cached(cached_file)
          uploaded_file(cached_file) do |file|
            real_metadata = file.open { cache.extract_metadata(file, context) }
            file.metadata.update(real_metadata)
          end

          super(cached_file)
        end
      end
    end

    register_plugin(:restore_cached_data, RestoreCachedData)
  end
end
