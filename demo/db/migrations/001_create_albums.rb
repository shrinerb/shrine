Sequel.migration do
  change do
    create_table(:albums) do
      primary_key :id
      String :name
    end
  end
end
