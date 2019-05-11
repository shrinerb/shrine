require "./config/sequel"
require "./uploaders/dynamic_image_uploader"

class Photo < Sequel::Model
  include DynamicImageUploader::Attachment.new(:image)  # ImageUploader will attach and manage `image`
end
