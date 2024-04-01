require File.expand_path("../lib/shrine/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name         = "shrine"
  gem.version      = Shrine.version

  gem.required_ruby_version = ">= 2.3"

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

  gem.homepage     = "https://shrinerb.com"
  gem.authors      = ["Janko Marohnić"]
  gem.email        = ["janko.marohnic@gmail.com"]
  gem.license      = "MIT"
  gem.metadata     = {
    "bug_tracker_uri"   => "https://github.com/shrinerb/shrine/issues",
    "changelog_uri"     => "https://github.com/shrinerb/shrine/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://shrinerb.com",
    "mailing_list_uri"  => "https://discourse.shrinerb.com",
    "source_code_uri"   => "https://github.com/shrinerb/shrine",
  }

  gem.files        = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb", "shrine.gemspec", "doc/**/*.md"]
  gem.require_path = "lib"

  gem.add_dependency "down", "~> 5.1"
  gem.add_dependency "content_disposition", "~> 1.0"

  # general testing helpers
  gem.add_development_dependency "appraisal", "~> 2.5"
  gem.add_development_dependency "rake", ">= 11.1"
  gem.add_development_dependency "minitest", "~> 5.8"
  gem.add_development_dependency "mocha", "~> 1.11"

  # for endpoint plugins
  gem.add_development_dependency "rack", ">= 2", "< 4"
  gem.add_development_dependency "http-form_data", "~> 2.2"
  gem.add_development_dependency "rack-test_app"

  # for determine_mime_type plugin
  gem.add_development_dependency "mimemagic", ">= 0.3.2"
  gem.add_development_dependency "marcel"
  gem.add_development_dependency "ruby-filemagic", "~> 0.7" unless RUBY_ENGINE == "jruby" || ENV["CI"]

  # for determine_mime_type and infer_extension plugins
  gem.add_development_dependency "mime-types"
  gem.add_development_dependency "mini_mime", "~> 1.0"

  # for store_dimensions plugin
  gem.add_development_dependency "fastimage"
  gem.add_development_dependency "mini_magick", "~> 4.0" unless ENV["CI"]
  gem.add_development_dependency "ruby-vips", "~> 2.0" unless ENV["CI"]

  # for S3 storage
  gem.add_development_dependency "aws-sdk-s3", "~> 1.69"
  gem.add_development_dependency "aws-sdk-core", "~> 3.23"
  gem.add_development_dependency "rexml"

  # for instrumentation plugin
  gem.add_development_dependency "dry-monitor"
  gem.add_development_dependency "activesupport", RUBY_VERSION >= "2.7" ? "~> 7.0" : RUBY_VERSION >= "2.5" ? "~> 6.0" : "~> 5.2"

  # for ORM plugins
  gem.add_development_dependency "sequel"
  gem.add_development_dependency "activerecord", RUBY_VERSION >= "2.7" ? "~> 7.0" : RUBY_VERSION >= "2.5" ? "~> 6.0" : "~> 5.2"
  gem.add_development_dependency "sqlite3", "~> 1.4" unless RUBY_ENGINE == "jruby"
end
