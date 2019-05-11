require "./uploaders/image_uploader"
require "image_processing/mini_magick"

# uploader showcasing on-the-fly processing
class DynamicImageUploader < ImageUploader
  plugin :derivation_endpoint, prefix: "derivations/image"

  derivation :thumbnail do |file, width, height|
    ImageProcessing::MiniMagick
      .source(file)
      .resize_to_limit(width.to_i, height.to_i)
      .convert("webp")
      .call
  end
end
