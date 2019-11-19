---
title: The Design of Shrine
---

*If you want an in-depth walkthrough through the Shrine codebase, see [Notes on
study of shrine implementation] article by Jonathan Rochkind.*

There are five main types of classes that you deal with in Shrine:

| Class | Description |
| :---- | :---------- |
| `Shrine::Storage::*` | Manages files on a particular storage service |
| `Shrine` | Wraps uploads and handles loading plugins |
| `Shrine::UploadedFile` | Represents a file uploaded to a storage |
| `Shrine::Attacher` | Handles file attachment logic |
| `Shrine::Attachment` | Provides convenience model attachment interface |

## Storage

On the lowest level we have a storage. A storage class encapsulates file
management logic on a particular service. It is what actually performs uploads,
generation of URLs, deletions and similar. By convention it is namespaced under
`Shrine::Storage::*`.

```rb
filesystem = Shrine::Storage::FileSystem.new("uploads")
filesystem.upload(file, "foo")
filesystem.url("foo") #=> "uploads/foo"
filesystem.delete("foo")
```

A storage is a PORO which implements the following interface:

```rb
class Shrine
  module Storage
    class MyStorage
      def upload(io, id, shrine_metadata: {}, **upload_options)
        # uploads `io` to the location `id`
      end

      def open(id, **options)
        # returns the remote file as an IO-like object
      end

      def exists?(id)
        # checks if the file exists on the storage
      end

      def delete(id)
        # deletes the file from the storage
      end

      def url(id, **options)
        # URL to the remote file, accepts options for customizing the URL
      end
    end
  end
end
```

Storages are typically not used directly, but through [`Shrine`](#shrine) and
[`Shrine::UploadedFile`](#shrine-uploadedfile) classes.

## `Shrine`

The `Shrine` class (also called an "uploader") primarily provides a wrapper
method around `Storage#upload`. First, the storage needs to be registered under
a name:

```rb
Shrine.storages[:disk] = Shrine::Storage::FileSystem.new("uploads")
```

Now we can upload files to the registered storage:

```rb
uploaded_file = Shrine.upload(file, :disk)
uploaded_file #=> #<Shrine::UploadedFile storage=:disk id="6a9fb596cc554efb" ...>
```

The argument to `Shrine#upload` must be an IO-like object. The method does the
following:

* generates a unique location
* extracts metadata
* uploads the file (calls `Storage#upload`)
* closes the file
* creates a `Shrine::UploadedFile` from the data

### Plugins

The `Shrine` class is also used for loading plugins, which provide additional
functionality by extending core classes.

```rb
Shrine.plugin :derivatives

Shrine::UploadedFile.ancestors #=> [..., Shrine::Plugins::Derivatives::FileMethods, Shrine::UploadedFile::InstanceMethods, ...]
Shrine::Attacher.ancestors     #=> [..., Shrine::Plugins::Derivatives::AttacherMethods, Shrine::Attacher::InstanceMethods,  ...]
Shrine::Attachment.ancestors   #=> [..., Shrine::Plugins::Derivatives::AttachmentMethods, Shrine::Attachment::InstanceMethods, ...]
```

The plugins store their configuration in `Shrine.opts`:

```rb
Shrine.plugin :derivation_endpoint, secret_key: "foo"
Shrine.plugin :default_storage, store: :other_store
Shrine.plugin :activerecord

Shrine.opts #=>
# { derivation_endpoint: { options: { secret_key: "foo" }, derivations: {} },
#   default_storage: { store: :other_store },
#   column: { serializer: Shrine::Plugins::Column::JsonSerializer },
#   model: { cache: true },
#   activerecord: { callbacks: true, validations: true } }
```

Each `Shrine` subclass has its own copy of the core classes, storages and
options, which makes it possible to customize attachment logic per uploader.

```rb
MyUploader = Class.new(Shrine)
MyUploader::UploadedFile.superclass #=> Shrine::UploadedFile
MyUploader::Attacher.superclass     #=> Shrine::Attacher
MyUploader::Attachment.superclass   #=> Shrine::Attachment
```

See [Creating a New Plugin] guide and the [Plugin system of Sequel and Roda]
article for more details on the design of Shrine's plugin system.

## `Shrine::UploadedFile`

A `Shrine::UploadedFile` object represents a file that was uploaded to a
storage, containing upload location, storage, and any metadata extracted during
the upload.

```rb
uploaded_file #=> #<Shrine::UploadedFile id="949sdjg834.jpg" storage=:store metadata={...}>

uploaded_file.id          #=> "949sdjg834.jpg"
uploaded_file.storage_key #=> :store
uploaded_file.storage     #=> #<Shrine::Storage::S3>
uploaded_file.metadata    #=> {...}
```

It has convenience methods for accessing metadata:

```rb
uploaded_file.metadata #=>
# {
#   "filename" => "matrix.mp4",
#   "mime_type" => "video/mp4",
#   "size" => 345993,
# }

uploaded_file.original_filename #=> "matrix.mp4"
uploaded_file.extension         #=> "mp4"
uploaded_file.mime_type         #=> "video/mp4"
uploaded_file.size              #=> 345993
```

It also has methods that delegate to the storage:

```rb
uploaded_file.url                     #=> "https://my-bucket.s3.amazonaws.com/949sdjg834.jpg"
uploaded_file.open { |io| ... }       # opens the uploaded file stream
uploaded_file.download { |file| ... } # downloads the uploaded file to disk
uploaded_file.stream(destination)     # streams uploaded content into a writable destination
uploaded_file.exists?                 #=> true
uploaded_file.delete                  # deletes the uploaded file from the storage
```

A `Shrine::UploadedFile` is itself an IO-like object (built on top of
`Storage#open`), so it can be passed to `Shrine#upload` as well.

## `Shrine::Attacher`

We usually want to treat uploaded files as *attachments* to records, saving
their data into a database column. This is done by `Shrine::Attacher`, which
internally uses `Shrine` and `Shrine::UploadedFile` classes.

The attaching process requires a temporary and a permanent storage to be
registered (by default that's `:cache` and `:store`):

```rb
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("uploads/cache"),
  store: Shrine::Storage::FileSystem.new("uploads/store"),
}
```

A `Shrine::Attacher` can be initialized standalone and handle the common
attachment flow, which includes dirty tracking (promoting cached file to
permanent storage, deleting previously attached file), validation, processing,
serialization etc.

```rb
attacher = Shrine::Attacher.new

# ... user uploads a file ...

attacher.assign(io) # uploads to temporary storage
attacher.file       #=> #<Shrine::UploadedFile storage=:cache ...>

# ... handle file validations ...

attacher.finalize   # uploads to permanent storage
attacher.file       #=> #<Shrine::UploadedFile storage=:store ...>
```

It can also be initialized with a model instance to handle serialization into a
model attribute:

```rb
attacher = Shrine::Attacher.from_model(photo, :image)

attacher.assign(file)
photo.image_data #=> "{\"storage\":\"cache\",\"id\":\"9260ea09d8effd.jpg\",\"metadata\":{...}}"

attacher.finalize
photo.image_data #=> "{\"storage\":\"store\",\"id\":\"ksdf02lr9sf3la.jpg\",\"metadata\":{...}}"
```

For more details, see the [Using Attacher] guide and
[`entity`][entity]/[`model`][model] plugins.

## `Shrine::Attachment`

A `Shrine::Attachment` module provides a convenience model interface around the
`Shrine::Attacher` object. The `Shrine::Attachment` class is a subclass of
`Module`, which means that an instance of `Shrine::Attachment` is a module:

```rb
Shrine::Attachment.new(:image).is_a?(Module) #=> true
Shrine::Attachment.new(:image).instance_methods #=> [:image=, :image, :image_url, :image_attacher, ...]

# equivalents
Shrine::Attachment.new(:image)
Shrine::Attachment[:image]
Shrine::Attachment(:image)
```

We can include this module into a model:

```rb
Photo.include Shrine::Attachment(:image)
```
```rb
photo.image = file   # shorthand for `photo.image_attacher.assign(file)`
photo.image          # shorthand for `photo.image_attacher.get`
photo.image_url      # shorthand for `photo.image_attacher.url`

photo.image_attacher #=> #<Shrine::Attacher @cache_key=:cache @store_key=:store ...>
```

When a persistence plugin is loaded ([`activerecord`][activerecord],
[`sequel`][sequel]), the `Shrine::Attachment` module also automatically:

* syncs Shrine's validation errors with the record
* triggers promoting after record is saved
* deletes the uploaded file if attachment was replaced or the record destroyed

[Using Attacher]: https://shrinerb.com/docs/attacher
[Notes on study of shrine implementation]: https://bibwild.wordpress.com/2018/09/12/notes-on-study-of-shrine-implementation/
[Creating a New Plugin]: https://shrinerb.com/docs/creating-plugins
[Plugin system of Sequel and Roda]: https://twin.github.io/the-plugin-system-of-sequel-and-roda/
[entity]: https://shrinerb.com/docs/plugins/entity
[model]: https://shrinerb.com/docs/plugins/model
[activerecord]: https://shrinerb.com/docs/plugins/activerecord
[sequel]: https://shrinerb.com/docs/plugins/sequel
