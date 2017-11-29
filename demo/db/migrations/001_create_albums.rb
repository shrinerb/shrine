Sequel.migration do
  change do
    create_table(:albums) do
      primary_key :id
      column :name, String
      column :cover_photo_data, String, text: true
    end
  end
end
