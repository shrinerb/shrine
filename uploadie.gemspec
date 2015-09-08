require_relative "lib/uploadie/version"

Gem::Specification.new do |gem|
  gem.name         = "uploadie"
  gem.version      = Uploadie.version

  gem.required_ruby_version = ">= 2.1"

  gem.summary      = "Uploading toolkit for Ruby applications"
  gem.description  = "Uploading toolkit for Ruby applications"
  gem.homepage     = "https://github.com/janko-m/uploadie"
  gem.authors      = ["Janko Marohnić"]
  gem.email        = ["janko.marohnic@gmail.com"]
  gem.license      = "MIT"

  gem.files        = Dir["README.md", "LICENSE.txt", "lib/**/*", "uploadie.gemspec"]
  gem.require_path = "lib"

  gem.add_development_dependency "minitest", "~> 5.8"
  gem.add_development_dependency "minitest-hooks", "~> 1.3.0"
  gem.add_development_dependency "mime-types", "~> 2.6"
  gem.add_development_dependency "mini_magick"
  gem.add_development_dependency "rmagick"
  gem.add_development_dependency "dimensions"
end
