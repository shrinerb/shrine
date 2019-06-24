# The Design of Shrine

*If you want an in-depth walkthrough through the Shrine codebase, see [Notes on study of shrine implementation] article by Jonathan Rochkind.*

There are five main types of objects that you deal with in Shrine:

* Storage
* `Shrine`
* `Shrine::UploadedFile`
* `Shrine::Attacher`
* `Shrine::Attachment`

## Storage

On the lowest level we have a storage. A storage class encapsulates file
management logic on a particular service. It is what actually performs uploads,
generation of URLs, deletions and similar. By convention it is namespaced under
`Shrine::Storage`.

```rb
filesystem = Shrine::Storage::FileSystem.new("uploads")
filesystem.upload(file, "foo")
filesystem.url("foo") #=> "uploads/foo"
filesystem.delete("foo")
```

A storage is a PORO which responds to certain methods:

```rb
class Shrine
  module Storage
    class MyStorage
      def upload(io, id, shrine_metadata: {}, **upload_options)
        # uploads `io` to the location `id`
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

      def url(id, options = {})
        # URL to the remote file, accepts options for customizing the URL
      end
    end
  end
end
```

Storages are typically not used directly, but through `Shrine`.

## `Shrine`

A `Shrine` object (also called an "uploader") is essentially a wrapper around
the `#upload` storage method. First the storage needs to be registered under a
name:

```rb
Shrine.storages[:file_system] = Shrine::Storage::FileSystem.new("uploads")
```

Now we can instantiate an uploader with this identifier and upload files:

```rb
uploader = Shrine.new(:file_system)
uploaded_file = uploader.upload(file)
uploaded_file #=> #<Shrine::UploadedFile>
```

The argument to `Shrine#upload` must be an IO-like object. The method does the
following:

* generates a unique location
* extracts metadata
* uploads the file (calls `Storage#upload`)
* closes the file
* creates a `Shrine::UploadedFile` from the data

`Shrine` class and subclasses are also used for loading plugins that extend all
core classes. Each `Shrine` subclass has its own subclass of each of the core
classes (`Shrine::UploadedFile`, `Shrine::Attacher`, and `Shrine::Attachment`),
which makes it possible to have different `Shrine` subclasses with differently
customized attachment logic. See [Creating a New Plugin] guide and the [Plugin
system of Sequel and Roda] article for more details on the design of Shrine's
plugin system.

## `Shrine::UploadedFile`

`Shrine::UploadedFile` represents a file that was uploaded to a storage, and is
the result of `Shrine#upload`. It is essentially a wrapper around a data hash
containing information about the uploaded file.

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

The data hash contains the storage the file was uploaded to, the location, and
some metadata: original filename, MIME type and filesize. The
`Shrine::UploadedFile` object has handy methods which use this data:

```rb
# metadata methods
uploaded_file.original_filename
uploaded_file.mime_type
uploaded_file.size
# ...

# storage methods
uploaded_file.url
uploaded_file.exists?
uploaded_file.open
uploaded_file.download
uploaded_file.delete
# ...
```

A `Shrine::UploadedFile` is itself an IO-like object (representing the
remote file), so it can be passed to `Shrine#upload` as well.

## `Shrine::Attacher`

We usually want to treat uploaded files as *attachments* to records, saving
their data into a database column. This is the responsibility of
`Shrine::Attacher`. A `Shrine::Attacher` uses `Shrine` uploaders and
`Shrine::UploadedFile` objects internally.

The attaching process requires a temporary and a permanent storage to be
registered (by default that's `:cache` and `:store`):

```rb
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("uploads/cache"),
  store: Shrine::Storage::FileSystem.new("uploads/store"),
}
```

A `Shrine::Attacher` is instantiated with a model instance and an attachment
name (an "image" attachment will be saved to `image_data` field):

```rb
attacher = Shrine::Attacher.new(photo, :image)

attacher.assign(file)
attacher.get #=> #<Shrine::UploadedFile>
attacher.record.image_data #=> "{\"storage\":\"cache\",\"id\":\"9260ea09d8effd.jpg\",\"metadata\":{...}}"

attacher._promote
attacher.get #=> #<Shrine::UploadedFile>
attacher.record.image_data #=> "{\"storage\":\"store\",\"id\":\"ksdf02lr9sf3la.jpg\",\"metadata\":{...}}"
```

Above a file is assigned by the attacher, which "caches" (uploads) the file to
the temporary storage. The cached file is then "promoted" (uploaded) to
permanent storage. Behind the scenes a cached `Shrine::UploadedFile` is given
to `Shrine#upload`, which works because `Shrine::UploadedFile` is an IO-like
object. After both caching and promoting the data hash of the uploaded file is
assigned to the record's column as JSON.

For more details see [Using Attacher].

## `Shrine::Attachment`

`Shrine::Attachment` is the highest level of abstraction. A
`Shrine::Attachment` module exposes the `Shrine::Attacher` object through the
model instance. The `Shrine::Attachment` class is a sublcass of `Module`, which
means that an instance of `Shrine::Attachment` is a module:

```rb
Shrine::Attachment.new(:image).is_a?(Module) #=> true
Shrine::Attachment.new(:image).instance_methods #=> [:image=, :image, :image_url, :image_attacher]

# equivalents
Shrine::Attachment.new(:image)
Shrine::Attachment(:image)
Shrine[:image]
```

We can include this module to a model:

```rb
class Photo
  include Shrine::Attachment.new(:image)
end
```
```rb
photo.image = file # shorthand for `photo.image_attacher.assign(file)`
photo.image        # shorthand for `photo.image_attacher.get`
photo.image_url    # shorthand for `photo.image_attacher.url`

photo.image_attacher #=> #<Shrine::Attacher>
```

When an ORM plugin is loaded, the `Shrine::Attachment` module also
automatically:

* syncs Shrine's validation errors with the record
* triggers promoting after record is saved
* deletes the uploaded file if attachment was replaced/removed or the record
  destroyed

[Using Attacher]: /doc/attacher.md#readme
[Notes on study of shrine implementation]: https://bibwild.wordpress.com/2018/09/12/notes-on-study-of-shrine-implementation/
[Creating a New Plugin]: /doc/creating_plugins.md#readme
[Plugin system of Sequel and Roda]: https://twin.github.io/the-plugin-system-of-sequel-and-roda/
