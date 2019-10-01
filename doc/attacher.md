# Using Attacher

This guide explains what is `Shrine::Attacher` and how to use it.

## Contents

* [Introduction](#introduction)
* [Storage](#storage)
* [Attaching](#attaching)
  - [Attaching cached](#attaching-cached)
  - [Attaching stored](#attaching-stored)
  - [Uploading](#uploading)
  - [Changes](#changes)
* [Finalizing](#finalizing)
  - [Promoting](#promoting)
  - [Replacing](#replacing)
* [Retrieving](#retreiving)
  - [File](#file)
  - [Attached](#attached)
  - [URL](#url)
  - [Data](#data)
* [Deleting](#deleting)
* [Context](#context)

## Introduction

The attachment logic is handled by a `Shrine::Attacher` object. The
`Shrine::Attachment` module simply provides a convenience layer around a
`Shrine::Attacher` object, which can be accessed via the `#<name>_attacher`
attribute.

```rb
class Photo
  include ImageUploader::Attachment(:image)
end
```
```rb
photo = Photo.new
photo.image_attacher #=> #<ImageUploader::Attacher>
```

We can also instantiate the same `Shrine::Attacher` object directly:

```rb
attacher = ImageUploader::Attacher.from_model(photo, :image)
attacher.file # called by `photo.image`
attacher.url  # called by `photo.image_url`
```

The [`model`][model], [`entity`][entity], and [`column`][column] plugins
provide additional `Shrine::Attacher` methods (such as
`Shrine::Attacher.from_model` we see above), but in this guide we'll focus only
on the core `Shrine::Attacher` methods.

So, we'll assume a `Shrine::Attacher` object not backed by any model/entity:

```rb
attacher = Shrine::Attacher.new
```

## Storage

By default, an `Attacher` will use the `:cache` storage as the **temporary**
storage, and the `:store` storage as the **permanent** storage.

```rb
Shrine.storages = {
  cache: Shrine::Storage::Memory.new,
  store: Shrine::Storage::Memory.new,
}
```
```rb
attacher = Shrine::Attacher.new
attacher.cache_key #=> :cache
attacher.store_key #=> :store
```

We can also change the default storage:

```rb
attacher = Shrine::Attacher.new(cache: :other_cache, store: :other_store)
attacher.cache_key #=> :other_cache
attacher.store_key #=> :other_store
```

You can also change default attacher options on the `Shrine::Attachment`
module:

```rb
class Photo
  include ImageUploader::Attachment(:image, cache: :other_cache, store: :other_store)
end
```

The `Attacher#cache` and `Attacher#store` methods will retrieve corresponding
uploaders:

```rb
attacher.cache #=> #<MyUploader @storage_key=:cache>
attacher.store #=> #<MyUploader @storage_key=:store>
```

## Attaching

### Attaching cached

For attaching files submitted via a web form, `Attacher#assign` can be used:

```rb
attacher.assign(file)
```

If given a raw file, it will upload it to temporary storage:

```rb
attacher.assign(file)
attacher.file #=> #<Shrine::UploadedFile @id="asdf.jpg", @storage_key=:cache>
```

If given cached file data (JSON or Hash), it will set the cached file:

```rb
attacher.assign('{"id":"asdf.jpg","storage":"cache","metadata":{...}}')
attacher.file #=> #<Shrine::UploadedFile @id="asdf.jpg", @storage_key=:cache>
```

If given an empty string, it will no-op:

```rb
attacher.assign("") # no-op
```

If given `nil`, it will clear the attached file:

```rb
attacher.file #=> <Shrine::UploadedFile>
attacher.assign(nil)
attacher.file #=> nil
```

This plays nicely with the recommended HTML form fields for the attachment. If
you're not using the `hidden` form field (and therefore don't need empty
strings to be handled), you can also use `Attacher#attach_cached`:

```rb
# uploads file to cache
attacher.attach_cached(file)

# sets cached file
attacher.attach_cached('{"id":"asdf.jpg","storage":"cache","metadata":{...}}')
attacher.attach_cached("id" => "asdf.jpg", "storage" => "cache", "metadata" => { ... })
attacher.attach_cached(id: "asdf.jpg", storage: "cache", metadata: { ... })

# unsets attached file
attacher.attach_cached(nil)
```

### Attaching stored

The `Attacher#attach` method uploads a given file to permanent storage:

```rb
attacher.attach(file)
attacher.file #=> #<Shrine::UploadedFile @id="asdf.jpg" @storage=:store>
```

This method is useful when attaching files from scripts, where validation
doesn't need to be performed, and where temporary storage can be skipped.

You can specify a different destination storage with the `:storage` option:

```rb
attacher.attach(file, storage: :other_store)
attacher.file #=> #<Shrine::UploadedFile @id="asdf.jpg" @storage=:other_store>
```

Any additional options passed to `Attacher#attach`, `Attacher#attach_cached`
and `Attacher#assign` are forwarded to the uploader:

```rb
attacher.attach(file, metadata: { "foo" => "bar" })       # adding metadata
attacher.attach(file, upload_options: { acl: "private" }) # setting upload options
attacher.attach(file, location: "path/to/file")           # setting upload location
```

### Uploading

If you want to upload a file to without attaching it, you can use
`Attacher#upload`:

```rb
attacher.upload(file)               #=> #<Shrine::UploadedFile @storage=:store ...>
attacher.upload(file, :cache)       #=> #<Shrine::UploadedFile @storage=:cache ...>
attacher.upload(file, :other_store) #=> #<Shrine::UploadedFile @storage=:other_store ...>
```

This is useful if you want to attacher [context](#context) such as `:record`
and `:name` to be automatically passed to the uploader.

You can also pass additional options for `Shrine#upload`:

```rb
attacher.upload(file, metadata: { "foo" => "bar" })       # adding metadata
attacher.upload(file, upload_options: { acl: "private" }) # setting upload options
attacher.upload(file, location: "path/to/file")           # setting upload location
```

### Changes

When a new file is attached, calling [`Attacher#finalize`](#finalization) will
perform additional actions such as promotion and deleting any previous file.
It will also trigger [validation].

You can check whether a new file has been attached with `Attacher#changed?`:

```rb
attacher.changed? #=> true
```

You can use `Attacher#change` to attach an `UploadedFile` object as is:

```rb
uploaded_file #=> #<Shrine::UploadedFile>
attacher.change(uploaded_file)
attacher.file #=> #<Shrine::UploadedFile> (same object)
attacher.changed? #=> true

```

If you want to attach a file without triggering dirty tracking or validation,
you can use `Attacher#set`:

```rb
uploaded_file #=> #<Shrine::UploadedFile>
attacher.set(uploaded_file)
attacher.file #=> #<Shrine::UploadedFile> (same object)
attacher.changed? #=> false
```

## Finalizing

After the file is attached (with `Attacher#assign`, `Attacher#attach_cached`,
or `Attacher#attach`), and data has been validated, the attachment can be
"finalized":

```rb
attacher.finalize
```

The `Attacher#finalize` method performs [promoting](#promoting) and
[replacing](#replacing). It also clears dirty tracking:

```rb
attacher.changed? #=> true
attacher.finalize
attacher.changed? #=> false
```

### Promoting

`Attacher#finalize` checks if the attached file has been uploaded to temporary
storage, and in this case uploads it to permanent storage.

```rb
attacher.attach_cached(io)
attacher.finalize # uploads attached file to permanent storage
attacher.file #=> #<Shrine::UploadedFile @storage=:store ...>
```

Internally it calls `Attacher#promote_cached`, which you can call directly if
you want to pass any promote options:

```rb
attacher.file #=> #<Shrine::UploadedFile @storage=:cache ...>
attacher.promote_cached # uploads attached file to permanent storage if new and cached
attacher.file #=> #<Shrine::UploadedFile @storage=:store ...>
```

You can also call `Attacher#promote` if you want to upload attached file to
permanent storage, regardless of whether it's cached or newly attached:

```rb
attacher.promote
```

Any options passed to `Attacher#promote_cached` or `Attacher#promote` will be
forwarded to `Shrine#upload`.

### Replacing

`Attacher#finalize` also deletes the previous attached file if any:

```rb
previous_file = attacher.file

attacher.attach(io)
attacher.finalize

previous_file.exists? #=> false
```

Internally it calls `Attacher#destroy_previous` to do this:

```rb
attacher.destroy_previous
```

## Retrieving

### File

The `Attacher#file` is used to retrieve the attached file:

```rb
attacher.file #=> #<Shrine::UploadedFile>
```

If no file is attached, `Attacher#file` returns nil:

```rb
attacher.file #=> nil
```

If you want to assert a file is attached, you can use `Attacher#file!`:

```rb
attacher.file! #~> Shrine::Error: no file is attached
```

### Attached

You can also check whether a file is attached with `Attacher#attached?`:

```rb
attacher.attached? # returns whether file is attached
```

If you want to check to which storage a file is uploaded to, you can use
`Attacher#cached?` and `Attacher#stored?`:

```rb
attacher.attach(io)
attacher.stored?                #=> true (checks current file)
attacher.stored?(attacher.file) #=> true (checks given file)
```
```rb
attacher.attach_cached(io)
attacher.cached?                #=> true (checks current file)
attacher.cached?(attacher.file) #=> true (checks given file)
```

### URL

The attached file URL can be retrieved with `Attacher#url`:

```rb
attacher.url #=> "https://example.com/file.jpg"
```

If no file is attached, `Attacher#url` returns `nil`:

```rb
attacher.url #=> nil
```

### Data

You can retrieve plain attached file data with `Attacher#data`:

```rb
attacher.data #=>
# {
#   "id" => "abc123.jpg",
#   "storage" => "store",
#   "metadata" => {
#     "size" => 223984,
#     "filename" => "nature.jpg",
#     "mime_type" => "image/jpeg",
#   }
# }
```

This data can be stored somewhere, and later the attached file can be loaded
from it:

```rb
# new attacher
attacher = Shrine::Attacher.from_data(data)
attacher.file #=> #<Shrine::UploadedFile>

# existing attacher
attacher.file #=> nil
attacher.load_data(data)
attacher.file #=> #<Shrine::UploadedFile>
```

Internally `Attacher#uploaded_file` is used to convert uploaded file data into
a `Shrine::UploadedFile` object:

```rb
attacher.uploaded_file("id" => "...", "storage" => "...", "metadata" => { ... }) #=> #<Shrine::UploadedFile>
attacher.uploaded_file(id: "...", storage: "...", metadata: { ... })             #=> #<Shrine::UploadedFile>
attacher.uploaded_file('{"id":"...","storage":"...","metadata":{...}}')          #=> #<Shrine::UploadedFile>
```

You will likely want to use a higher level abstraction for saving and loading
this data, see [`column`][column], [`entity`][entity] and [`model`][model]
plugins for more details.

## Deleting

The attached file can be deleted via `Attacher#destroy_attached`:

```rb
attacher.destroy_attached
```

This will not delete cached files, to not interrupt any potential
[backgrounding] that might be in process.

If you want to delete the attached file regardless of storage it's uploaded to,
you can use `Attacher#destroy`:

```rb
attacher.destroy
```

## Context

The `Attacher#context` hash is automatically forwarded to the uploader on
`Attacher#upload`. When [`model`][model] or [`entity`][model] plugin is loaded,
this will include `:record` and `:name` values:

```rb
attacher = Shrine::Attacher.from_model(photo, :image)
attacher.context #=> { record: #<Photo>, name: :image }
```

You can add here any other parameters you want to forward to the uploader:

```rb
attacher.context[:foo] = "bar"
```

However, it's generally better practice to pass uploader options directly to
`Attacher#assign`, `Attacher#attach`, `Attacher#promote` or any other method
that's calling `Attacher#upload`.

[validation]: /doc/plugins/validation.md#readme
[column]: /doc/plugins/column.md#readme
[entity]: /doc/plugins/entity.md#readme
[model]: /doc/plugins/model.md#readme
[backgrounding]: /doc/plugins/backgrounding.md#readme
