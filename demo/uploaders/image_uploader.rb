require "./config/shrine"
require "image_processing/mini_magick"

class ImageUploader < Shrine
  ALLOWED_TYPES = %w[image/jpeg image/png]
  MAX_SIZE      = 10*1024*1024 # 10 MB

  plugin :remove_attachment
  plugin :pretty_location
  plugin :processing
  plugin :versions
  plugin :validation_helpers
  plugin :store_dimensions, analyzer: :mini_magick

  Attacher.validate do
    validate_max_size MAX_SIZE
    if validate_mime_type_inclusion(ALLOWED_TYPES)
      validate_max_width 5000
      validate_max_height 5000
    end
  end

  process(:store) do |io, context|
    original = io.download

    thumbnail = ImageProcessing::MiniMagick
      .source(original)
      .resize_to_limit!(600, nil)

    original.close!

    { original: io, thumbnail: thumbnail }
  end
end
