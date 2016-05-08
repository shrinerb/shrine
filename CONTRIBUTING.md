Issue Guidelines
================

1. Issues should only be created for things that are definitely bugs.  If you
   are not sure that the behavior is a bug, ask about it on the [ruby-shrine]
   Google Group.

2. If you are sure it is a bug, then post a complete description of the issue,
   the simplest possible self-contained example showing the problem (see
   Sequel/ActiveRecord templates below), and the full backtrace of any
   exception.

Pull Request Guidelines
=======================

1. Try to include tests for all new features and substantial bug
   fixes.

2. Try to include documentation for all new features.  In most cases
   this should include RDoc method documentation, but updates to the
   README is also appropriate in some cases.

3. Follow the style conventions of the surrounding code.  In most
   cases, this is standard ruby style.

Running tests
=============

The test suite requires that you have the following installed:

* [libmagic]
* [SQLite]

If you're using Homebrew, you can just run `brew bundle`. The test suite is
best run using Rake:

```sh
$ rake test
```

You can also automatically run tests accross Ruby versions:

```sh
$ bin/test-versions
```

Code of Conduct
===============

Everyone interacting in the Shrine project’s codebases, issue trackers, chat
rooms, and mailing lists is expected to follow the [Shrine code of conduct].

Appendix A: Sequel template
============================

```rb
require "sequel"
require "shrine"
require "shrine/storage/file_system"
require "tmpdir"
require "open-uri"

Shrine.plugin :sequel
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new(Dir.tmpdir, prefix: "cache"),
  store: Shrine::Storage::FileSystem.new(Dir.tmpdir, prefix: "store"),
}

class MyUploader < Shrine
  # plugins and uploading logic
end

DB = Sequel.sqlite # SQLite memory database
DB.create_table :posts do
  primary_key :id
  column :image_data, :text
end

class Post < Sequel::Model
  include MyUploader[:image]
end

post = Post.create(image: open("https://example.com/image-from-internet.jpg"))

# Your code for reproducing
```

Appendix B: ActiveRecord template
=================================

```rb
require "active_record"
require "shrine"
require "shrine/storage/file_system"
require "tmpdir"
require "open-uri"

Shrine.plugin :activerecord
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new(Dir.tmpdir, prefix: "cache"),
  store: Shrine::Storage::FileSystem.new(Dir.tmpdir, prefix: "store"),
}

class MyUploader < Shrine
  # plugins and uploading logic
end

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.connection.create_table(:posts) { |t| t.text :image_data }
# make errors propagate when raised in callbacks
ActiveRecord::Base.raise_in_transactional_callbacks = true

class Post < ActiveRecord::Base
  include MyUploader[:image]
end

post = Post.create(image: open("https://example.com/image-from-internet.jpg"))

# Your code for reproducing
```

[ruby-shrine]: https://groups.google.com/forum/#!forum/ruby-shrine
[Shrine code of conduct]: https://github.com/janko-m/shrine/blob/master/CODE_OF_CONDUCT.md
[libmagic]: https://github.com/threatstack/libmagic
[SQLite]: https://www.sqlite.org
