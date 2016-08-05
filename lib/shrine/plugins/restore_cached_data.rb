class Shrine
  module Plugins
    # The restore_cached_data re-extracts cached file's metadata on assignment.
    # This happens when an uploaded file is retained on validation errors, or
    # when assigning direct uploaded files. In both cases you usually want to
    # re-extract metadata on the server side, mainly to prevent tempering, but
    # also in case of direct uploads to obtain metadata that couldn't be
    # extracted on the client side.
    #
    #     plugin :restore_cached_data
    #
    # This will give an opened `UploadedFile` for metadata extraction. For
    # remote storages this will make an HTTP request, and since metadata is
    # typically found in the beginning of the file, Shrine will download only
    # the amount of bytes necessary for extracting the metadata.
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
