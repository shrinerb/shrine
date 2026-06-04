source "https://rubygems.org"

gemspec

gem "stringio"

gem "simplecov"
gem "hanna", require: false

gem "activerecord-jdbcsqlite3-adapter", "~> 72.1", platform: :jruby if RUBY_ENGINE == "jruby"
gem "zeitwerk", "~> 2.6.0" if RUBY_ENGINE == "jruby"
