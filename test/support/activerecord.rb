require "active_record"

ActiveRecord::Base.establish_connection(
  adapter:  RUBY_ENGINE == "jruby" ? "jdbcsqlite3" : "sqlite3",
  database: ":memory:",
)

ActiveRecord::Base.connection.create_table(:users) do |t|
  t.string :name
  t.text :avatar_data
end
