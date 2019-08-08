# Writing a Storage

Shrine ships with the FileSystem and S3 storages, but it's also easy to create
your own. A storage is a class which needs to implement `#upload`, `#url`,
`#open`, `#exists?`, and `#delete` methods.

```rb
class Shrine
  module Storage
    class MyStorage
      def upload(io, id, shrine_metadata: {}, **upload_options)
        # uploads `io` to the location `id`, can accept upload options
      end

      def open(id, **options)
        # returns the remote file as an IO-like object
      end

      def url(id, **options)
        # returns URL to the remote file, can accept URL options
      end

      def exists?(id)
        # returns whether the file exists on storage
      end

      def delete(id)
        # deletes the file from the storage
      end
    end
  end
end
```

## Upload

The `#upload` storage method is called by `Shrine#upload`, it accepts an IO
object (`io`) and upload location (`id`) and is expected to upload the IO
content to the specified location. It's also given `:shrine_metadata` that was
extracted from the IO, which can be used for specifying request headers on
upload. The storage can also support custom upload options (which can be
utilized with the `upload_options` plugin).

```rb
class MyStorage
  # ...
  def upload(io, id, shrine_metadata: {}, **upload_options)
    # uploads `io` to the location `id`, can accept upload options
  end
  # ...
end
```

Unless you're already using a Ruby SDK, it's recommended to use [HTTP.rb] for
uploading. It accepts any IO object that implements `IO#read` (not just file
objects), and it streams the request body directly to the TCP socket, both for
raw and multipart uploads, making it suitable for large uploads.

```rb
require "http"

# streaming raw upload
HTTP.post("http://example.com/upload", body: io)
# streaming multipart upload
HTTP.post("http://example.com/upload", form: { file: HTTP::FormData::File.new(io) })
```

It's good practice to test the storage with a [fake IO] object which responds
only to required methods, as not all received IO objects will be file objects.

If your storage doesn't control which id the uploaded file will have, you
can modify the `id` variable before returning:

```rb
def upload(io, id, shrine_metadata: {}, **upload_options)
  # ...
  id.replace(actual_id)
end
```

Likewise, if you need to save some information into the metadata after upload
(e.g. if the MIME type of the file changes on upload), you can modify the
metadata hash:

```rb
def upload(io, id, shrine_metadata: {}, **upload_options)
  # ...
  shrine_metadata.merge!(returned_metadata)
end
```

## Open

The `#open` storage method is called by various `Shrine::UploadedFile` methods
that retrieve uploaded file content. It accepts the file location and is
expected to return an IO-like object (that implements `#read`, `#size`,
`#rewind`, `#eof?`, and `#close`) that represents the uploaded file.


```rb
class MyStorage
  # ...
  def open(id, **options)
    # returns the remote file as an IO-like object
  end
  # ...
end
```

Ideally, the returned IO object should lazily retrieve uploaded content, so
that in cases where metadata needs to be extracted from an uploaded file, only
a small portion of the file will be downloaded.

It's recommended to use the [Down] gem for this. If the storage exposes its
files over HTTP, you can use `Down.open`, otherwise if it's possible to stream
chunks of content from the storage, that can be wrapped in a `Down::ChunkedIO`.
It's recommended to use the [`Down::Http`] backend, as the [HTTP.rb] gem
allocates an order of magnitude less memory when reading the response body
compared to `Net::HTTP`.

The storage can support additional options to customize how the file will be
opened, `Shrine::UploadedFile#open` and `Shrine::UploadedFile#download` will
forward any given options to `#open`.

## Url

The `#url` storage method is called by `Shrine::UploadedFile#url`, it accepts a
file location and is expected to return a resolvable URL to the uploaded file.
Custom URL options can be supported if needed, `Shrine::UploadedFile#url` will
forward any given options to `#url`.

```rb
class MyStorage
  # ...
  def url(id, **options)
    # returns URL to the remote file, can accept URL options
  end
  # ...
end
```

If the storage does not have uploaded files accessible via HTTP, the `#url`
method should return `nil`. Note that in this case users can use the
`download_endpoint` or `rack_response` plugins to create a downloadable link,
which are implemented in terms of `#open`.

## Exists

The `#exists?` storage method is called by `Shrine::UploadedFile#exists?`, it
accepts a file location and should return `true` if the file exists on the
storage and `false` otherwise.

```rb
class MyStorage
  # ...
  def exists?(id)
    # returns whether the file exists on storage
  end
  # ...
end
```

## Delete

The `#delete` storage method is called by `Shrine::UploadedFile#delete`, it
accepts a file location and is expected to delete the file from the storage.

```rb
class MyStorage
  # ...
  def delete(id)
    # deletes the file from the storage
  end
  # ...
end
```

For convenience of use, this method should not raise an exception if the file
doesn't exist.

## Presign

If the storage service supports direct uploads, and requires fetching
additional information from the server, you can implement a `#presign` method,
which will be called by the `presign_endpoint` plugin. The `#presign` method
should return a Hash with the following keys:

* `:method` – HTTP verb that should be used
* `:url` – URL to which the file should be uploaded to
* `:fields` – Hash of request parameters that should be used for the upload (optional)
* `:headers` – Hash of request headers that should be used for the upload (optional)

```rb
class MyStorage
  # ...
  def presign(id, **options)
    # returns a Hash with :method, :url, :fields, and :headers keys
  end
  # ...
end
```

The storage can support additional options to customize how the presign will be
generated, those can be forwarded via the `:presign_options` option on the
`presign_endpoint` plugin.

## Clear

While this method is not used by Shrine, it is good to give users the
possibility to delete all files in a storage, and the conventional name for
this method is `#clear!`.

```rb
class MyStorage
  # ...
  def clear!
    # deletes all files in the storage
  end
  # ...
end
```

## Update

If your storage supports updating data of existing files (e.g. some metadata),
the convention is to create an `#update` method:

```rb
class MyStorage
  # ...
  def update(id, **options)
    # update data of the file
  end
  # ...
end
```

## Linter

To check that your storage implements all these methods correctly, you can use
`Shrine::Storage::Linter`:

```rb
require "shrine/storage/linter"

storage = Shrine::Storage::MyStorage.new(*args)
linter = Shrine::Storage::Linter.new(storage)
linter.call
```

The linter will test your methods with fake IO objects, and raise a
`Shrine::LintError` if any part of the contract isn't satisfied.

If you want to specify the IO object to use for testing (e.g. you need the IO
to be an actual image), you can pass in a lambda which returns the IO when
called:

```rb
linter.call(->{File.open("test/fixtures/image.jpg")})
```

If you don't want errors to be raised but rather only warnings, you can
pass `action: :warn` when initializing

```rb
linter = Shrine::Storage::Linter.new(storage, action: :warn)
```

Note that using the linter doesn't mean that you shouldn't write any manual
tests for your storage. There will likely be some edge cases that won't be
tested by the linter.

[HTTP.rb]: https://github.com/httprb/http
[fake IO]: https://github.com/shrinerb/shrine/blob/master/test/support/fakeio.rb
[Down]: https://github.com/janko/down
[`Down::Http`]: https://github.com/janko/down#httprb
