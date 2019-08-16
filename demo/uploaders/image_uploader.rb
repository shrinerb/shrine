# This is a subclass of Shrine base that will be further configured for it's requirements.
# This will be included in the model to manage the file.

require "./config/shrine"
require "image_processing/mini_magick"
require "dry-initializer"

class ImageUploader < Shrine
  ALLOWED_TYPES  = %w[image/jpeg image/png image/webp]
  MAX_SIZE       = 10*1024*1024 # 10 MB
  MAX_DIMENSIONS = [5000, 5000] # 5000x5000

  THUMBNAIL_SIZES = {
    small:  [300, 300],
    medium: [600, 600],
    large:  [800, 800],
  }

  class ThumbnailGenerator
    extend Dry::Initializer

    option :processor, default: proc { ImageProcessing::MiniMagick }

    def call(original, width, height)
      processor
        .source(original)
        .resize_to_limit!(width, height)
    end
  end

  THUMBNAILER = ThumbnailGenerator.new

  plugin :remove_attachment
  plugin :pretty_location
  plugin :validation_helpers
  plugin :store_dimensions, analyzer: :mini_magick
  plugin :derivatives, versions_compatibility: true
  plugin :derivation_endpoint, prefix: "derivations/image"

  # File validations (requires `validation_helpers` plugin)
  Attacher.validate do
    validate_size 0..MAX_SIZE

    if validate_mime_type ALLOWED_TYPES
      validate_max_dimensions MAX_DIMENSIONS
    end
  end

  # Thumbnails processor (requires `derivatives` plugin)
  Attacher.derivatives_processor :thumbnails do |original|
    {
      small:  THUMBNAILER.call(original, *THUMBNAIL_SIZES.fetch(:small)),
      medium: THUMBNAILER.call(original, *THUMBNAIL_SIZES.fetch(:medium)),
      large:  THUMBNAILER.call(original, *THUMBNAIL_SIZES.fetch(:large)),
    }
  end

  # Default to dynamic thumbnail URL (requires `default_url` plugin)
  Attacher.default_url do |derivative: nil, **|
    file&.derivation_url(:thumbnail, *THUMBNAIL_SIZES.fetch(derivative)) if derivative
  end

  # Dynamic thumbnail definition (requires `derivation_endpoint` plugin)
  derivation :thumbnail do |file, width, height|
    THUMBNAILER.call(file, width.to_i, height.to_i)
  end
end
