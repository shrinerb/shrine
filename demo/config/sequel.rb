require "sequel"

DB = Sequel.sqlite("database.sqlite3")

Sequel::Model.plugin :nested_attributes
Sequel::Model.plugin :association_dependencies
Sequel::Model.plugin :validation_helpers
