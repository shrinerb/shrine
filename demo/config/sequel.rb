require "sequel"

DB = Sequel.sqlite("database.sqlite3")
Sequel::Model.plugin :nested_attributes
