source "https://rubygems.org"

gemspec

gem "stringio"

gem "simplecov"
gem "hanna", require: false

gem "activerecord-jdbcsqlite3-adapter", "~> 80.0.pre1", platform: :jruby if RUBY_ENGINE == "jruby"
gem "zeitwerk", "~> 2.6.0" if RUBY_ENGINE == "jruby"

# JRuby 10.1 corrupts zero-byte files on gem extraction (jruby/jruby#8669),
# and aws-sdk-kms > 1.111 ships a zero-byte customizations.rb
gem "aws-sdk-kms", "< 1.112" if RUBY_ENGINE == "jruby"
