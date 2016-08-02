Sequel.migration do
  change do
    create_table(:photos) do
      primary_key :id
      foreign_key :album_id, :albums
      String :image_data, text: true
    end
  end
end
