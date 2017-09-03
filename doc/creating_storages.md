# Creating a New Storage

## Essentials

Shrine ships with the FileSystem and S3 storages, but it's also easy to create
your own. A storage is a class which needs to implement to the following
methods:

```rb
class Shrine
  module Storage
    class MyStorage
      def upload(io, id, shrine_metadata: {}, **upload_options)
        # uploads `io` to the location `id`, can accept upload options
      end

      def url(id, **options)
        # returns URL to the remote file, accepts options for customizing the URL
      end

      def open(id)
        # returns the remote file as an IO-like object
      end

      def exists?(id)
        # checks if the file exists on the storage
      end

      def delete(id)
        # deletes the file from the storage
      end
    end
  end
end
```

## Upload

The job of `Storage#upload` is to upload the given IO object to the storage.
It's good practice to test the storage with a [fake IO] object which responds
only to required methods. Some HTTP libraries don't support uploading non-file
IOs, although for [Faraday] and [REST client] you can work around that.

If your storage doesn't control which id the uploaded file will have, you
can modify the `id` variable before returning:

```rb
def upload(io, id, shrine_metadata: {}, **upload_options)
  # ...
  id.replace(actual_id)
end
```

Likewise, if you need to save some information into the metadata after upload,
you can modify the metadata hash:

```rb
def upload(io, id, shrine_metadata: {}, **upload_options)
  # ...
  shrine_metadata.merge!(returned_metadata)
end
```

## Download

Shrine automatically downloads the file to a Tempfile using `#open`. However,
if you would like to do custom downloading, you can define `#download` and
Shrine will use that instead:

```rb
class Shrine
  module Storage
    class MyStorage
      # ...

      def download(id)
        # download the file to a Tempfile
      end

      # ...
    end
  end
end
```

## Presign

If the storage service supports direct uploads, and requires fetching
additional information from the server, you can implement a `#presign` method,
which will be used by the `presign_endpoint` plugin. The method should return an
object which responds to

* `#url` – returns the URL to which the file should be uploaded to
* `#fields` – returns a `Hash` of request parameters that should be used for the upload
* `#headers` – returns a `Hash` of request headers that should be used for the upload (optional)

```rb
class Shrine
  module Storage
    class MyStorage
      # ...

      def presign(id, **options)
        # returns an object which responds to #url and #presign
      end

      # ...
    end
  end
end
```

## Move

If your storage can move files, you can add 2 additional methods, and they will
automatically get used by the `moving` plugin:

```rb
class Shrine
  module Storage
    class MyStorage
      # ...

      def move(io, id, **upload_options)
        # does the moving of the `io` to the location `id`
      end

      def movable?(io, id)
        # whether the given `io` is movable to the location `id`
      end

      # ...
    end
  end
end
```

## Multi delete

If your storage supports deleting multiple files at the same time, you can
implement an additional method, which will automatically get picked up by the
`multi_delete` plugin:

```rb
class Shrine
  module Storage
    class MyStorage
      # ...

      def multi_delete(ids)
        # deletes multiple files at once
      end

      # ...
    end
  end
end
```

## Clearing

While this method is not used by Shrine, it is good to give users the
possibility to delete all files in a storage, and the conventional name for
this method is `#clear!`:

```rb
class Shrine
  module Strorage
    class MyStorage
      # ...

      def clear!
        # deletes all files in the storage
      end

      # ...
    end
  end
end
```

## Update

If your storage supports updating data of existing files (e.g. some metadata),
the convention is to create an `#update` method:

```rb
class Shrine
  module Storage
    class MyStorage
      # ...

      def update(id, options = {})
        # update data of the file
      end

      # ...
    end
  end
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

[fake IO]: https://github.com/janko-m/shrine-cloudinary/blob/ca587c580ea0762992a2df33fd590c9a1e534905/test/test_helper.rb#L20-L27
[REST client]: https://github.com/janko-m/shrine-cloudinary/blob/ca587c580ea0762992a2df33fd590c9a1e534905/lib/shrine/storage/cloudinary.rb#L138-L141
[Faraday]: https://github.com/janko-m/shrine-uploadcare/blob/2038781ace0f54d82fa06cc04c4c2958919208ad/lib/shrine/storage/uploadcare.rb#L140
