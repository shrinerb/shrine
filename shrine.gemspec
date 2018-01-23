require File.expand_path("../lib/shrine/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name         = "shrine"
  gem.version      = Shrine.version

  gem.required_ruby_version = ">= 2.1"

  gem.summary      = "Toolkit for file attachments in Ruby applications"
  gem.description  = <<-END
Shrine is a toolkit for file attachments in Ruby applications. It supports
uploading, downloading, processing and deleting IO objects, backed by various
storage engines. It uses efficient streaming for low memory usage.

Shrine comes with a high-level interface for attaching uploaded files to
database records, saving their location and metadata to a database column, and
tying them to record's lifecycle. It natively supports background jobs and
direct uploads for fully asynchronous user experience.
  END

  gem.homepage     = "https://github.com/janko-m/shrine"
  gem.authors      = ["Janko Marohnić"]
  gem.email        = ["janko.marohnic@gmail.com"]
  gem.license      = "MIT"

  gem.files        = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb", "shrine.gemspec", "doc/*.md"]
  gem.require_path = "lib"

  gem.add_dependency "down", "~> 4.1"

  gem.add_development_dependency "rake", ">= 11.1"
  gem.add_development_dependency "minitest", "~> 5.8"
  gem.add_development_dependency "minitest-hooks", "~> 1.3"
  gem.add_development_dependency "mocha"
  gem.add_development_dependency "rack-test_app"
  gem.add_development_dependency "shrine-memory", ">= 0.2.2"

  gem.add_development_dependency "roda"
  gem.add_development_dependency "rack"
  gem.add_development_dependency "mimemagic", ">= 0.3.2"
  gem.add_development_dependency "marcel" if RUBY_VERSION >= "2.2.0"
  gem.add_development_dependency "mime-types"
  gem.add_development_dependency "mini_mime", "~> 1.0"
  gem.add_development_dependency "fastimage"
  gem.add_development_dependency "aws-sdk-s3", "~> 1.2"

  unless RUBY_ENGINE == "jruby" || ENV["CI"]
    gem.add_development_dependency "ruby-filemagic", "~> 0.7"
  end

  gem.add_development_dependency "sequel"
  gem.add_development_dependency "activerecord", "~> 4.2"

  if RUBY_ENGINE == "jruby"
    gem.add_development_dependency "activerecord-jdbcsqlite3-adapter", "1.3.24"
  else
    gem.add_development_dependency "sqlite3"
  end
end
