require "./config/sequel"

class Album < Sequel::Model
  one_to_many :photos
  nested_attributes :photos, destroy: true
end
