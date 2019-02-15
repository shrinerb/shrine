require "./config/sequel"
require "./uploaders/image_uploader"

class Album < Sequel::Model
  one_to_many :photos
  nested_attributes :photos, destroy: true
  add_association_dependencies photos: :destroy

  include ImageUploader::Static::Attachment.new(:cover_photo)  # ImageUploader will attach and manage `cover_photo`

  def validate
    super
    validates_presence [:name, :cover_photo]  # Normal model validations - optional
  end
end
