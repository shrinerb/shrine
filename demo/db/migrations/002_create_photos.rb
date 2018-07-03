Sequel.migration do
  change do
    create_table(:photos) do
      primary_key :id
      foreign_key :album_id, :albums
      column :title, String
      column :image_data, String, text: true  # Shrine will store the file info here for the photo's image
    end
  end
end
