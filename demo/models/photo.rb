require "./config/sequel"
require "./uploaders/image_uploader"

class Photo < Sequel::Model
  include ImageUploader::Attachment(:image)  # ImageUploader will attach and manage `image`
end
