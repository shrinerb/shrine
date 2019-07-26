require "./uploaders/image_uploader"
require "image_processing/mini_magick"

# uploader showcasing processing on-upload
class StaticImageUploader < ImageUploader
  plugin :processing
  plugin :versions

  # Additional processing (requires `processing` plugin)
  process(:store) do |io, options|
    original = io.download

    thumbnail = ImageProcessing::MiniMagick
      .source(original)
      .resize_to_limit!(600, nil)

    original.close!

    { original: io, thumbnail: thumbnail }  # Hash of versions requires `versions` plugin
  end
end
