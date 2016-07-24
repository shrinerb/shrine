require File.expand_path("../lib/shrine/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name         = "shrine"
  gem.version      = Shrine.version

  gem.required_ruby_version = ">= 2.1"

  gem.summary      = "Toolkit for handling file uploads in Ruby"
  gem.description  = <<-END
Shrine is a toolkit for handling file uploads in Ruby. It supports uploading,
processing and deleting IO objects, backed by a storage adapter. It uses
efficient streaming to minimize memory usage.

Shrine comes with a high-level attachment interface for attaching uploaded
files to database records, saving their location and metadata to a database
column, and tying them to record's lifecycle.
  END

  gem.homepage     = "https://github.com/janko-m/shrine"
  gem.authors      = ["Janko Marohnić"]
  gem.email        = ["janko.marohnic@gmail.com"]
  gem.license      = "MIT"

  gem.files        = Dir["README.md", "LICENSE.txt", "lib/**/*.rb", "shrine.gemspec", "doc/*.md"]
  gem.require_path = "lib"

  gem.add_dependency "down", ">= 2.3.5"

  gem.add_development_dependency "rake", "~> 11.1"
  gem.add_development_dependency "minitest", "~> 5.8"
  gem.add_development_dependency "minitest-hooks", "~> 1.3.0"
  gem.add_development_dependency "mocha"
  gem.add_development_dependency "webmock"
  gem.add_development_dependency "rack-test_app"
  gem.add_development_dependency "dotenv"
  gem.add_development_dependency "shrine-memory", ">= 0.2.1"

  gem.add_development_dependency "roda"
  gem.add_development_dependency "rack", "~> 1.6.4"
  gem.add_development_dependency "mimemagic"
  gem.add_development_dependency "mime-types"
  gem.add_development_dependency "fastimage"
  gem.add_development_dependency "aws-sdk", "~> 2.1"

  unless RUBY_ENGINE == "jruby" || ENV["CI"]
    gem.add_development_dependency "ruby-filemagic", "~> 0.7"
  end

  gem.add_development_dependency "sequel"
  gem.add_development_dependency "activerecord", "~> 4.2"

  if RUBY_ENGINE == "jruby"
    gem.add_development_dependency "activerecord-jdbcsqlite3-adapter"
  else
    gem.add_development_dependency "sqlite3"
  end
end
