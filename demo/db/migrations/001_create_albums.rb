Sequel.migration do
  change do
    create_table(:albums) do
      primary_key :id

      String :name
      String :cover_photo_data  # Shrine will store the file info here for the album's cover_photo
    end
  end
end
