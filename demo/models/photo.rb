require "./config/sequel"
require "./uploaders/image_uploader"

class Photo < Sequel::Model
  include ImageUploader[:image]
end
