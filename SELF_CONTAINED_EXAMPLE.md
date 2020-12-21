# Simple, Self-contained Example

## Option 1: Clone the repository below

It is very difficult to debug a problem without a simple example.

You can [clone this repository](https://github.com/benkoshy/debugging-shrine-example) here with everything set up, to make this as easy as possible to debug.

But if you wish to set things up manually, please follow the guide lines below.

## Option 2: Manually set up the self-contained Example:


Appendix A: Sequel template
============================

```rb
require "sequel"
require "shrine"
require "shrine/storage/memory"
require "down"

Shrine.storages = {
  cache: Shrine::Storage::Memory.new,
  store: Shrine::Storage::Memory.new,
}

Shrine.plugin :sequel

class MyUploader < Shrine
  # plugins and uploading logic
end

DB = Sequel.sqlite # SQLite memory database
DB.create_table :posts do
  primary_key :id
  String :image_data
end

class Post < Sequel::Model
  include MyUploader::Attachment(:image)
end

post = Post.create(image: Down.download("https://example.com/image-from-internet.jpg"))

# Your code for reproducing
```

Appendix B: ActiveRecord template
=================================

```rb
require "active_record"
require "shrine"
require "shrine/storage/memory"
require "down"

Shrine.storages = {
  cache: Shrine::Storage::Memory.new,
  store: Shrine::Storage::Memory.new,
}

Shrine.plugin :activerecord

class MyUploader < Shrine
  # plugins and uploading logic
end

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.connection.create_table(:posts) { |t| t.text :image_data }

class Post < ActiveRecord::Base
  include MyUploader::Attachment(:image)
end

post = Post.create(image: Down.download("https://example.com/image-from-internet.jpg"))

# Your code for reproducing
```

Appendix C: Running the Templates
=================================
 
You can either:

* Create a Gemfile and add the necessary gems. 

* Inline the required gems in the script - if you don't want to create a Gemfile.

### Create a Gemfile and Add Gems (Option 1)

```ruby
# Gemfile
source 'https://rubygems.org' do
  gem "activerecord" # replace with gem "sequel" if you're using it
  gem 'shrine'
  gem "down"
end
```

1. Run `bundle install`.

2. Run the template with: `ruby template_name.rb`.

### In-lining them Gems in your script (Option 2)

* Add the following to the above ****template script**** (not a Gemfile)

```ruby
## template_name.rb
## Append the following to the top of the ruby template script
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem "activerecord" # replace with gem "sequel" if you're using it
  gem 'shrine'
end

# include the rest of the template script below:
```

* Run the template with `ruby template_name.rb`.

Appendix D: Debugging Shrine code
=================================

If you would like to debug or step through Shrine's code using the above template scripts, follow these steps:

1. Download (or clone) Shrine's repository to your local machine
   `git clone https://github.com/shrinerb/shrine.git` (or you could create a fork of the above repository and clone your fork - this will make it easier for you if you want to make a pull request). 
   
2. Checkout the version of shrine you are using by running `git checkout <version_tag>`.

3. Modify the Shrine gem line in your `Gemfile` to point to the local copy of Shrine code:

```ruby
  gem "shrine", path: "/path/to/your/local/shrine/gem/code" 
```

4. If needed, add a debugger like `byebug` or `pry` to the `Gemfile`.

5. Run `bundle install`.

6. Add `require "bundler/setup"` to the top of the template script.

7. You can add debugger statement anywhere in your template file or Shrine code.

8. Run `ruby template_name.rb`. 

[forum]: https://discourse.shrinerb.com
[Shrine code of conduct]: https://github.com/shrinerb/shrine/blob/master/CODE_OF_CONDUCT.md
[libmagic]: https://github.com/threatstack/libmagic
[libvips]: https://github.com/libvips/libvips/wiki
[SQLite]: https://www.sqlite.org
[Design of Shrine]: /doc/design.md#readme
[Creating a New Plugin]: /doc/creating_plugins.md#readme
[Plugin system of Sequel and Roda]: https://twin.github.io/the-plugin-system-of-sequel-and-roda/
[Notes on study of shrine implementation]: https://bibwild.wordpress.com/2018/09/12/notes-on-study-of-shrine-implementation/
