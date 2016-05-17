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

        def assign_cached(value)
          cached_file = uploaded_file(value) do |cached_file|
            next unless cache.uploaded?(cached_file)
            real_metadata = cache.extract_metadata(cached_file.to_io, context)
            cached_file.metadata.update(real_metadata)
            cached_file.close
          end

          super(cached_file)
        end
      end
    end

    register_plugin(:restore_cached_data, RestoreCachedData)
  end
end
