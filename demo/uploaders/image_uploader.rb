require "./config/shrine"
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick

  plugin :remove_attachment
  plugin :pretty_location
  plugin :processing
  plugin :versions
  plugin :validation_helpers

  Attacher.validate do
    validate_mime_type_inclusion %w[image/jpeg image/png image/gif]
  end

  process(:store) do |io, context|
    small = resize_to_limit!(io.download, 300, 300) { |cmd| cmd.auto_orient }

    {original: io, small: small}
  end
end
