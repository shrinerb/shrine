require "sequel"

DB = Sequel.connect("#{"jdbc:" if RUBY_ENGINE == "jruby"}sqlite::memory:")

DB.create_table :users do
  primary_key :id
  String :name
  String :avatar_data
end
