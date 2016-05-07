# The Design of Shrine

There are five main types of objects that you deal with in Shrine:

* Storage
* `Shrine`
* `Shrine::UploadedFile`
* `Shrine::Attacher`
* `Shrine::Attachment`

## Storage

A storage class encapsulates file management logic on a particular service. It
is what actually performs uploads, generation of URLs, deletions and similar. By
convention it is namespaced under `Shrine::Storage`.

```rb
filesystem = Shrine::Storage::FileSystem.new("uploads")
filesystem.upload(file, "foo")
filesystem.url("foo") #=> "uploads/foo"
filesystem.delete("foo")
```

All storages conform to the same unified interface:

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

      # ...
    end
  end
end
```

## `Shrine`

Storages are typically not used directly, but through an uploader which acts as
a wrapper around the storage. An uploader is any descendant of `Shrine`. In
order for an uploader to wrap a storage, we first have to register the storage
under a name:

```rb
Shrine.storages[:file_system] = Shrine::Storage::FileSystem.new("uploads")
```

Now we can instantiate an uploader with this identifier, and upload files:

```rb
uploader = Shrine.new(:file_system)
uploaded_file = uploader.upload(file)
uploaded_file #=> #<Shrine::UploadedFile>
```

The argument to `Shrine#upload` must be an IO-like object. The method does the
following:

* generates a unique location
* extracts metadata
* uploads the file
* closes the file
* creates a `Shrine::UploadedFile` from the data

## `Shrine::UploadedFile`

`Shrine::UploadedFile` represents a file that was uploaded to a storage. It is
essentially a wrapper around a data hash containing all the information about
the uploaded file.

```rb
uploaded_file      #=> #<Shrine::UploadedFile>
uploaded_file.data #=>
# {
#   "storage"  => "file_system",
#   "id"       => "9260ea09d8effd.pdf",
#   "metadata" => {
#     "filename"  => "resume.pdf",
#     "mime_type" => "application/pdf",
#     "size"      => 983294,
#   },
# }
```

As we can see, the data hash contains the storage the file was uploaded to,
the location, and some metadata: original filename, MIME type and filesize.
The `Shrine::UploadedFile` object has handy methods which use this data:

```rb
# metadata methods
uploaded_file.original_filename
uploaded_file.mime_type
uploaded_file.size
# ...

# storage methods
uploaded_file.url
uploaded_file.exists?
uploaded_file.download
uploaded_file.delete
# ...
```

A `Shrine::UploadedFile` is itself an IO-like object (representing the
remote file), so it can be passed to `Shrine#upload` as well.

## `Shrine::Attacher`

We want to treat uploaded files as *attachments* to records, saving their data
into a database column. This is the responsibility of `Shrine::Attacher`. The
attaching process requires a temporary and a permanent storage to be
registered (by default that's `:cache` and `:store`):

```rb
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("uploads/cache"),
  store: Shrine::Storage::FileSystem.new("uploads/store"),
}
```

A file can be assigned to the attacher, which will "cache" (upload) the file to
the temporary storage. After validations pass, the cached file can be
"promoted" (uploaded) to permanent storage. Behind the scenes a cached
`Shrine::UploadedFile` is given to `Shrine#upload`, which works because
`Shrine::UploadedFile` is an IO-like object. After both caching and promoting
the data hash of the uploaded file is saved to the record's column as JSON.

```rb
attacher = Shrine::Attacher.new(photo, :image)

attacher.assign(file)
attacher.get #=> #<Shrine::UploadedFile>
attacher.record.image_data #=> "{\"storage\":\"cache\",\"id\":\"9260ea09d8effd.jpg\",\"metadata\":{...}}"

attacher._promote
attacher.get #=> #<Shrine::UploadedFile>
attacher.record.image_data #=> "{\"storage\":\"store\",\"id\":\"ksdf02lr9sf3la.jpg\",\"metadata\":{...}}"
```

## `Shrine::Attachment`

A `Shrine::Attachment` module exposes the attacher for an attachment through
the record. The `Shrine::Attachment` class is a sublcass of `Module`, which
means that an instance of `Shrine::Attachment` is a module:

```rb
Shrine::Attachment.new(:image).is_a?(Module) #=> true
Shrine::Attachment.new(:image).instance_methods #=> [:image=, :image, :image_url, :image_attacher]

# equivalents
Shrine::Attachment.new(:image)
Shrine.attachment(:image)
Shrine[:image]
```

We can include this module to a model:

```rb
class Photo
  include Shrine[:image]
end
```
```rb
photo.image = file # shorthand for `photo.image_attacher.assign(file)`
photo.image        # shorthand for `photo.image_attacher.get`
photo.image_url    # shorthand for `photo.image_attacher.url`

photo.image_attacher #=> #<Shrine::Attacher>
```

When an ORM plugin is loaded, the `Shrine::Attachment` module also adds
callbacks for uploading the cached file to permanent storage when record is
saved, and for deleting the file when it was replaced, removed, or the record
was destroyed.
