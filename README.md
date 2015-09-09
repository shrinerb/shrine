# Uploadie

Uploadie is a file uploading toolkit for Ruby applications.

## Installation

Add the gem to your Gemfile:

```ruby
gem 'uploadie'
```

## Usage

```rb
require "uploadie"
require "uploadie/storage/file_system"
require "tmpdir"

Uploadie.cache = Uploadie::Storage::FileSystem.new(Dir.tmpdir)
Uploadie.store = Uploadie::Storage::FileSystem.new("uploads", root: "public")

# Basic

cache = Uploadie.new(:cache)
store = Uploadie.new(:store)

cached_file = cache.upload(File.open("path/to/image.jpg"))
cached_file      #=> Uploadie::UploadedFile
cached_file.data #=> {"storage" => "temporary", "id" => "09c7876a-d33a-4279-a860-41b7d5cb0272.jpg", "metadata" => {}}
cached_file.url  #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/09c7876a-d33a-4279-a860-41b7d5cb0272.jpg"

stored_file = store.upload(cached_file)
stored_file      #=> Uploadie::UploadedFile
stored_file.data #=> {"storage" => "permanent", "id" => "avatar/23alsd05l/image.jpg", "metadata" => {}}
stored_file.url  #=> "/uploads/avatar/23alsd05l/image.jpg"

# Advanced

class AvatarUploader < Uploadie
  plugin :preserve_filename
  plugin :store_dimensions
  plugin :store_original_filename
  plugin :store_content_type
  plugin :attachment
  plugin :versions, storage: :cache
  plugin :endpoint, storage: :cache
end

class User < ActiveRecord::Base
  extend AvatarUploader::Attachment
  attachment :avatar
end
```

## Code of Conduct

This project is intended to be a safe, welcoming space for collaboration, and
contributors are expected to adhere to the [Contributor
Covenant](contributor-covenant.org) code of conduct.

## Thanks

TODO: Heavily inspired by Refile and Roda

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
