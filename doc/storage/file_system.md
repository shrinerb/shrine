# Shrine::Storage::FileSystem

The FileSystem storage handles uploads to the filesystem, and it is most
commonly initialized with a "base" folder and a "prefix":

```rb
require "shrine/storage/file_system"

storage = Shrine::Storage::FileSystem.new("public", prefix: "uploads")
storage.url("image.jpg") #=> "/uploads/image.jpg"
```

This storage will upload all files to "public/uploads", and the URLs of the
uploaded files will start with "/uploads/\*". This way you can use FileSystem
for both cache and store, one having the prefix "uploads/cache" and other
"uploads/store". If you're uploading files to the `public` directory itself,
you need to set `:prefix` to `"/"`:

```rb
storage = Shrine::Storage::FileSystem.new("public", prefix: "/") # no prefix
storage.url("image.jpg") #=> "/image.jpg"
```

You can also initialize the storage just with the "base" directory, and then
the FileSystem storage will generate absolute URLs to files:

```rb
storage = Shrine::Storage::FileSystem.new(Dir.tmpdir)
storage.url("image.jpg") #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/image.jpg"
```

## Host

It's generally a good idea to serve your files via a CDN, so an additional
`:host` option can be provided to `#url`:

```rb
storage = Shrine::Storage::FileSystem.new("public", prefix: "uploads")
storage.url("image.jpg", host: "http://abc123.cloudfront.net")
#=> "http://abc123.cloudfront.net/uploads/image.jpg"
```

If you're not using a CDN, it's recommended that you still set `:host` to your
application's domain (at least in production).

The `:host` option can also be used wihout `:prefix`, and is useful if you for
example have files located on another server:

```rb
storage = Shrine::Storage::FileSystem.new("/opt/files")
storage.url("image.jpg", host: "http://943.23.43.1")
#=> "http://943.23.43.1/opt/files/image.jpg"
```

## Moving

If you're uploading files on disk and want to improve performance, you can tell
the `FileSystem#upload` method to **move** files instead of copying them:

```rb
storage.upload(file, "/path/to/destination", move: true) # performs the `mv` command

File.exist?(file.path) #=> false
```

If you want to make this option default, you can use the
[`upload_options`][upload_options] plugin.

## Path

You can retrieve path to the file using `#path`:

```rb
storage.path("image.jpg") #=> #<Pathname:public/image.jpg>
```

## Deleting prefixed

If you want to delete all files in some directory, you can use
`FileSystem#delete_prefixed`:

```rb
storage.delete_prefixed("some_directory/") # deletes all files in "some_directory/"
```

## Clearing cache

If you're using FileSystem as cache, you will probably want to periodically
delete old files which aren't used anymore. You can run something like this
periodically:

```rb
file_system = Shrine.storages[:cache]
file_system.clear! { |path| path.mtime < Time.now - 7*24*60*60 } # delete files older than 1 week
```

## Permissions

The storage sets the default UNIX permissions to 0644 for files and 0755 for
directories, but you can change that:

```rb
Shrine::Storage::FileSystem.new("directory", permissions: 0644)
Shrine::Storage::FileSystem.new("directory", directory_permissions: 0755)
```

## Heroku

Note that Heroku has a read-only filesystem, and doesn't allow you to upload
your files to the "public" directory, you can however upload to "tmp"
directory:

```rb
Shrine::Storage::FileSystem.new("tmp/uploads")
```

Note that this approach has a couple of downsides. For example, you can only
use it for cache, since Heroku wipes this directory between app restarts. This
also means that deploying the app can cancel someone's uploading if you're
using backgrounding. Also, by default you cannot generate URLs to files in the
"tmp" directory, but you can with the `download_endpoint` plugin.

[upload_options]: /doc/plugins/upload_options.md#readme
