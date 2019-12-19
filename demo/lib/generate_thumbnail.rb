require "image_processing/mini_magick"

class GenerateThumbnail
  def self.call(file, width, height)
    magick = ImageProcessing::MiniMagick.source(file)
    magick.resize_to_limit!(width, height)
  end
end
