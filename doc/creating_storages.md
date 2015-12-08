# Creating a New Storage

Shrine ships with the FileSystem and S3 storages, but it's also easy to create
your own. A storage is a class which has at least the following methods:

```rb
class Shrine
  module Storage
    class MyStorage
      def initialize(*args)
        # initializing logic
      end

      def upload(io, id, metadata = {})
        # uploads `io` to the location `id`
      end

      def download(id)
        # downloads the file from the storage
      end

      def open(id)
        # returns the remote file as an IO-like object
      end

      def read(id)
        # returns the file contents as a string
      end

      def exists?(id)
        # checks if the file exists on the storage
      end

      def delete(id)
        # deletes the file from the storage
      end

      def url(id, options = {})
        # URL to the remote file, accepts options for customizing the URL
      end

      def clear!(confirm = nil)
        # deletes all the files in the storage
      end
    end
  end
end
```

To check that your storage implements all these methods correctly, you can use
`Shrine::Storage::Linter` in tests:

```rb
require "shrine/storage/linter"

storage = Shrine::Storage::MyStorage.new(*args)
Shrine::Storage::Linter.call(storage)
```

The linter will pass real files through your storage, and raise an error with
an appropriate message if a part of the specification isn't satisfied.

## Moving

If your storage can move files, you can add 2 additional methods, and they will
automatically get used by the `moving` plugin:

```rb
class Shrine
  module Storage
    class MyStorage
      # ...

      def move(io, id, metadata = {})
        # does the moving of the `io` to the location `id`
      end

      def movable?(io, id)
        # whether the given `io` is movable, to the location `id`
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
