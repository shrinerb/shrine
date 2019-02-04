# Using Attacher

The most convenient way to use Shrine is through the model, using the interface
provided by Shrine's attachment module. This way you can interact with the
attachment just like with any other column attribute, and adding attachment
fields to the form just works.

```rb
class Photo < Sequel::Model
  include ImageUploader::Attachment.new(:image)
end
```

However, you don't want to add additional methods on the model and prefer
explicitness, or you need more control, you can achieve the same behaviour
using the `Shrine::Attacher` object, which is what the attachment interface
uses under the hood.

```rb
attacher = ImageUploader::Attacher.new(photo, :image) # equivalent to `photo.image_attacher`
attacher.assign(file)                                 # equivalent to `photo.image = file`
attacher.get                                          # equivalent to `photo.image`
```

## Attributes

The attacher object exposes the objects it uses:

```rb
attacher.record #=> #<Photo>
attacher.name   #=> :image
attacher.cache  #=> #<ImageUploader @storage_key=:cache>
attacher.store  #=> #<ImageUploader @storage_key=:store>
```

The attacher will automatically use `:cache` and `:store` storages, but you can
also tell it to use different temporary and permanent storage:

```rb
ImageUploader::Attacher.new(photo, :image, cache: :other_cache, store: :other_store)
```

Note that you can pass the `:cache` and `:store` options via `Attachment.new` too:

```rb
class Photo < Sequel::Model
  include ImageUploader::Attachment.new(:image, cache: :other_cache, store: :other_store)
end
```

The attacher will use the `<attachment>_data` attribute for storing information
about the attachment.

```rb
attacher.data_attribute #=> :image_data
```

## Assignment

The `#assign` method accepts either an IO object to be cached, or an already
cached file in form of a JSON string, and assigns the cached result to record's
`<attachment>_data` attribute.

```rb
# uploads the `io` object to temporary storage, and writes to the data column
attacher.assign(io)

# writes the given cached file to the data column
attacher.assign('{"id":"9260ea09d8effd.jpg","storage":"cache","metadata":{ ... }}')
```

When assigning an IO object, any additional options passed to `#assign` will be
forwarded to `Shrine#upload`. This allows you to do things like overriding
metadata, setting upload location, or passing upload options:

```rb
attacher.assign io,
  metadata:       { "filename" => "myfile.txt" },
  location:       "custom/location",
  upload_options: { acl: "public-read" }
```

If you're attaching a cached file and want to override its metadata before
assignment, you can do it like so:

```rb
cached_file = Shrine.uploaded_file('{"id":"9260ea09d8effd.jpg","storage":"cache","metadata":{ ... }}')
cached_file.metadata["filename"] = "myfile.txt"

attacher.assign(cached_file.to_json)
```

For security reasons `#assign` doesn't accept files uploaded to permanent
storage, but you can use `#set` to attach any `Shrine::UploadedFile` object.

```rb
uploaded_file #=> #<Shrine::UploadedFile>
attacher.set(uploaded_file)
```

## Retrieval

The `#get` method reads record's `<attachment>_data` attribute, and constructs
a `Shrine::UploadedFile` object from it.

```rb
attacher.get #=> #<Shrine::UploadedFile>
```

The `#read` method will just return the value of the underlying
`<attachment>_data` attribute.

```rb
attacher.read #=> '{"id":"dsg024lfs.jpg","storage":"cache","metadata":{...}}'
```

In general you can use `#uploaded_file` to contruct a `Shrine::UploadedFile`
from a JSON string.

```rb
attachment_data = '{"id":"dsg024lfs.jpg","storage":"cache","metadata":{...}}'
attacher.uploaded_file(attachment_data) #=> #<Shrine::UploadedFile>
```

## URL

The `#url` method returns the URL to the attached file, and returns `nil` if
no file is attached.

```rb
attacher.url # calls `attacher.get.url`
```

## State

You can ask the attacher whether the currently attached file is cached or
stored.

```rb
attacher.cached?
attacher.stored?
```

## Validations

Whenever a file is assigned via `#assign` or `#set`, the file validations are
automatically run, and you can access the validation errors through `#errors`:

```rb
attacher.assign(large_file)
attacher.errors #=> ["is larger than 10 MB"]
```

## Promoting

After the attachment is assigned and you run validations, it should be promoted
to permanent storage after the record is saved. You can use `#finalize` for
that, since that will also automatically delete any previously attached files.

```rb
# Replaces previous attachment and replaces new
attacher.finalize
```

This is normally automatically added to a callback by the ORM plugin when going
through the model. Internally this calls `#promote`, which uploads a given
`Shrine::UploadedFile` to permanent storage, and swaps it with the current
attachment, unless a new file was attached in the meanwhile.

```rb
# uploads cached file to permanent storage and replaces the current one
attacher.promote(cached_file, action: :custom_name)
```

The `:action` parameter is optional; it can be used for triggering a certain
processing block, and it is also automatically printed by the `logging` plugin
to aid in debugging.

As a matter of fact, all additional options passed to `#promote` will be
forwarded to `Shrine#upload`. So unless you're generating versions, you can do
things like override metadata, set upload location, or pass upload options:

```rb
attacher.promote cached_file,
  metadata:       { "filename" => "myfile.txt" },
  location:       "custom/location",
  upload_options: { acl: "public-read" }
```

Internally `#promote` calls `#swap`, which will update the record with any
uploaded file, but will reload the record to check if the current attachment
hasn't changed (if the `backgrounding` plugin is loaded).

```rb
attacher.swap(uploaded_file)
```

Both `#promote` and `#swap` are useful for [file migrations].

## Backgrounding

When the `backgrounding` plugin is loaded, it allows you to promote and delete
files in the background, and the corresponding methods are prefixed with `_`:

```rb
Shrine.plugin :backgrounding
Shrine::Attacher.promote { |data| PromoteJob.perform_async(data) }
Shrine::Attacher.delete { |data| DeleteJob.perform_async(data) }
```
```rb
attacher._promote(cached_file)  # calls the registered `Attacher.promote` block
attacher._delete(uploaded_file) # calls the registered `Attacher.delete` block
```

These are automatically used when using Shrine through models.

## Context

The attacher sends `#context` to each upload/delete call to the uploader. By
default it will hold `:record` and `:name`:

```rb
attacher.context #=>
# {
#   record: #<Photo...>,
#   name:   :image,
# }
```

However, you can change/add additional context to be sent when calling the
uploaders:

```rb
attacher.context[:foo] = "bar"
```

This is useful for example if you have immutable model instances, and you want
to assign a new updated instance. For example both foreground and background
`#promote` requires that the record is persisted (and its `#id` is present).

## Uploading and deleting

Normally you can upload and delete directly by using the uploader.

```rb
uploader = ImageUploader.new(:store)
uploaded_file = uploader.upload(image) # uploads the file to `:store` storage
uploader.delete(uploaded_file)         # deletes the uploaded file from `:store`
```

But the attacher also has wrapper methods for uploading and deleting, which
also automatically pass in the attacher `#context` (which includes `:record`
and `:name`):

```rb
attacher.cache!(file) # uploads file to temporary storage
# => #<Shrine::UploadedFile: @data={"storage" => "cache", ...}>
attacher.store!(file) # uploads file to permanent storage
# => #<Shrine::UploadedFile: @data={"storage" => "store", ...}>
attacher.delete!(uploaded_file) # deletes uploaded file from storage
```

These methods only upload/delete files, they don't write to record's data
column. You can also pass additional options for `Shrine#upload` and
`Shrine#delete`:

```rb
attacher.cache!(file, upload_options: { acl: "public-read" })
attacher.store!(file, location: "custom/location")
attacher.delete!(uploaded_file, foo: "bar")
```

[file migrations]: doc/migrating_storage.md
