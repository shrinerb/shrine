---
id: retrieving-uploads
title: Retrieving Uploads
---

Uploaded file content is typically retrieved from the storage using a
`Shrine::UploadedFile` object. This guide explains the various methods of
retrieving file content and how do they work.

For context, `Shrine::UploadedFile` object is what is returned by the
attachment reader method on the model instance (e.g. `photo.image`),
`Shrine::Attacher#get` if you're using the attacher directly, or
`Shrine#upload` if you're using the uploader directly.

## IO-like interface

In order for `Shrine::UploadedFile` objects to be uploadable to a storage, they
too conform to Shrine's IO-like interface, meaning they implement `#read`,
`#rewind`, `#eof?`, and `#close` matching the behaviour of the same methods on
Ruby's IO class.

```rb
uploaded_file.eof?   # => false
uploaded_file.read   # => "..."
uploaded_file.eof?   # => true
uploaded_file.rewind # rewinds the underlying IO object
uploaded_file.eof?   # => false
uploaded_file.close  # closes the underlying IO object (this should be called when you're done)
```

These methods are simply delegated on the IO object returned by the
`Storage#open` method of the underlying Shrine storage. `Storage#open` is
implicitly called when any of these IO methods are called for the first time.

```rb
uploaded_file.read(10) # calls `Storage#open` and assigns result to an instance variable
uploaded_file.read(10)
# ...
```

You can retrieve the underlying IO object returned by `Storage#open` with
`#to_io`:

```rb
uploaded_file.to_io # the underlying IO object returned by `Storage#open`
```

## `Storage#open`

The underlying IO object that `Shrine::UploadedFile` will use depends on the
storage. The `FileSystem` storage will return a `File` object, while `S3` and
most other remote storages will return [`Down::ChunkedIO`] that downloads file
content on-demand.

```rb
Shrine.storages = {
  file_system: Shrine::Storage::FileSystem.new(...),
  s3:          Shrine::Storage::S3.new(...),
}

local_file = Shrine.upload(file, :file_system)
local_file.to_io #=> #<File:/path/to/file>

remote_file = Shrine.upload(file, :s3)
remote_file.to_io #=> #<Down::ChunkedIO> (opens HTTP connection)
remote_file.read(1*1024*1024) # downloads first 1MB
remote_file.read(1*1024*1024) # downloads next 1MB
remote_file.close # closes HTTP connection
```

The `Down::ChunkedIO` object will cache downloaded content to disk in order to
be rewindable, which is used in a places such as metadata extraction.

```rb
remote_file.read(1*1024*1024) # downloads and caches first 1MB
remote_file.rewind
remote_file.read(1*1024*1024) # reads first 1MB from the cache
remote_file.read(1*1024*1024) # downloads and caches next 1MB
```

If you want to turn off caching to disk, most storages allow you to pass
`:rewindable` to `Storage#open`:

```rb
remote_file.open(rewindable: false)
remote_file.read(1*1024*1024) # downloads first 1MB (no caching to disk)
remote_file.rewind #~> IOError: this Down::ChunkedIO is not rewindable
```

## Opening

The `Shrine::UploadedFile#open` method can be used to open the uploaded file
explicitly:

```rb
uploaded_file.open # calls `Storage#open` and assigns result to an instance variable
uploaded_file.read
uploaded_file.close
```

This is useful if you want to control where `Storage#open` will be called. It's
also useful if you want to pass additional parameters to `Storage#open`, which
will depend on the storage. For example, if you're using S3 storage and
server-side encryption, you can pass the necessary server-side-encryption
parameters to `Shrine::Storage::S3#open`:

```rb
# server-side encryption parameters for S3 storage
uploaded_file.open(
 sse_customer_algorithm: "AES256",
 sse_customer_key:       "secret_key",
 sse_customer_key_md5:   "secret_key_md5",
)
```

`Shrine::UploadedFile#open` also accepts a block, which will ensure that the
underlying IO object is closed at the end of the block.

```rb
uploaded_file.open do
  uploaded_file.read(1000)
  # ...
end # underlying IO object is closed
```

`Shrine::UploadedFile#open` will return the result of a given block.
We can use that to safely retrieve the whole content of a file, without
leaving any temporary files lying around.

```rb
content = uploaded_file.open(&:read) # open, read, and close
content # uploaded file content
```

## Streaming

The `Shrine::UploadedFile#stream` method can be used to stream uploaded file
content to a writable destination object.

```rb
destination = StringIO.new # from the "stringio" standard library
uploaded_file.stream(destination)
destination.rewind

destination # holds the file content
```

The destination object can be any object that responds to `#write` and returns
number of bytes written, or a path string.

`Shrine::UploadedFile#stream` will play nicely with
`Shrine::UploadedFile#open`, meaning it will not re-open the uploaded file if
it's already opened.

```rb
uploaded_file.open do
  uploaded_file.stream(destination)
end
```

Any additional parameters to `Shrine::UploadeFile#stream` are forwarded to
`Storage#open`. For example, if you're using S3 storage, you can tell AWS S3 to
use HTTP compression for the download request:

```rb
uploaded_file.stream(destination, response_content_encoding: "gzip")
```

If you want to stream uploaded file content to the response body in a Rack
application (Rails, Sinatra, Roda etc), see the `rack_response` plugin.

## Downloading

The `Shrine::UploadedFile#download` method can be used to download uploaded
file content do disk. Internally a temporary file will be created (using the
`tempfile` standard library) and passed to `Shrine::UploadedFile#stream`. The
return value is an open `Tempfile` object (a delegate of the `File` class).

```rb
tempfile = uploaded_file.download
tempfile #=> #<Tempfile:...>

tempfile.path   #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/20181227-2915-m2l6c1"
tempfile.read   #=> "..."
tempfile.close! # close and unlink
```

Like `Shrine::UploadedFile#open`, `Shrine::UploadedFile#download` accepts a
block as well. The `Tempfile` object is yielded to the block, and after the
block finishes it's automatically closed and deleted.

```rb
uploaded_file.download do |tempfile|
  tempfile.path   #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/20181227-2915-m2l6c1"
  tempfile.read   #=> "..."
  # ...
end # tempfile is closed and deleted
```

Since `Shrine::UploadedFile#download` internally uses
`Shrine::UploadedFile#stream`, it plays nicely with `Shrine::UploadedFile#open`
as well, meaning it will only open the uploaded file if it's not already
opened.

```rb
uploaded_file.open do
  tempfile = uploaded_file.download
  # ...
end
```

Any options passed to `Shrine::UploadedFile#download` are forwarded to
`Storage#open` (unless the uploaded file was already opened, in which case
`Storage#open` was already called). For example, if you're using S3 storage,
you can tell AWS S3 to use HTTP compression for the download request:

```rb
uploaded_file.download(response_content_encoding: "gzip")
```

Every time `Shrine::UploadedFile#download` is called, it will make a new copy
of the uploaded file content. If you plan to retrieve uploaded file content
multiple times for the same `Shrine::UploadedFile` instance, consider using the
`tempfile` plugin.

[`Down::ChunkedIO`]: https://github.com/janko/down#streaming
