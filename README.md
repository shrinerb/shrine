# Uploadie

Uploadie is my attempt at solving file uploads in Ruby.

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

Uploadie.storages = {
  temporary: Uploadie::Storage::FileSystem.new(Dir.tmpdir),
  permanent: Uploadie::Storage::FileSystem.new("uploads", root: "public"),
}

cache = Uploadie.new(:temporary)
store = Uploadie.new(:permanent)

cached_file = cache.upload(File.open("path/to/image.jpg"))
cached_file      #=> Uploadie::File
cached_file.data #=> {"storage" => "temporary", "id" => "avatar/kr92l23nf/image.jpg", "metadata" => {}}
cached_file.url  #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/avatar/kr92l23nf/image.jpg"

stored_file = store.upload(cached_file)
stored_file      #=> Uploadie::File
stored_file.data #=> {"storage" => "permanent", "id" => "avatar/23alsd05l/image.jpg", "metadata" => {}}
stored_file.url  #=> "/uploads/avatar/23alsd05l/image.jpg"
```

## Code of Conduct

This project is intended to be a safe, welcoming space for collaboration, and
contributors are expected to adhere to the [Contributor
Covenant](contributor-covenant.org) code of conduct.

## Thanks

TODO: Heavily inspired by Refile and Roda

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
