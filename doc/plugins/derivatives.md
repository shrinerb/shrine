---
title: Derivatives
---

The derivatives plugin allows storing processed files ("derivatives") alongside
the main attached file. The processed file data will be saved together with the
main attachment data in the same record attribute.

```rb
Shrine.plugin :derivatives
```

## Quick start

You'll usually want to create derivatives from an attached file. The simplest
way to do this is to define a processor which returns the processed files, and
then trigger it when you want to create derivatives.

Here is an example of generating image thumbnails:

```rb
# Gemfile
gem "image_processing", "~> 1.8"
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  Attacher.derivatives do |original|
    magick = ImageProcessing::MiniMagick.source(original)

    {
      small:  magick.resize_to_limit!(300, 300),
      medium: magick.resize_to_limit!(500, 500),
      large:  magick.resize_to_limit!(800, 800),
    }
  end
end
```
```rb
class Photo < Model(:image_data)
  include ImageUploader::Attachment(:image)
end
```
```rb
photo = Photo.new(image: file)
photo.image_derivatives! # calls derivatives processor and uploads results
photo.save
```

If you're allowing the attached file to be updated later on, in your update
route make sure to create derivatives for new attachments:

```rb
photo.image_derivatives! if photo.image_changed?
```

You can then retrieve created derivatives as follows:

```rb
photo.image(:large)           #=> #<Shrine::UploadedFile ...>
photo.image(:large).url       #=> "https://s3.amazonaws.com/path/to/large.jpg"
photo.image(:large).size      #=> 43843
photo.image(:large).mime_type #=> "image/jpeg"
```

The derivatives data is stored in the `#<name>_data` record attribute, alongside
the main file data:

```rb
photo.image_data #=>
# {
#   "id": "original.jpg",
#   "store": "store",
#   "metadata": { ... },
#   "derivatives": {
#     "small": { "id": "small.jpg", "storage": "store", "metadata": { ... } },
#     "medium": { "id": "medium.jpg", "storage": "store", "metadata": { ... } },
#     "large": { "id": "large.jpg", "storage": "store", "metadata": { ... } },
#   }
# }
```

## Retrieving derivatives

The list of stored derivatives can be retrieved with `#<name>_derivatives`:

```rb
photo.image_derivatives #=>
# {
#   small:  #<Shrine::UploadedFile ...>,
#   medium: #<Shrine::UploadedFile ...>,
#   large:  #<Shrine::UploadedFile ...>,
# }
```

A specific derivative can be retrieved in any of the following ways:

```rb
photo.image_derivatives[:small] #=> #<Shrine::UploadedFile ...>
photo.image_derivatives(:small) #=> #<Shrine::UploadedFile ...>
photo.image(:small)             #=> #<Shrine::UploadedFile ...>
```

Or with nested derivatives:

```rb
photo.image_derivatives #=> { thumbnail: { small: ..., medium: ..., large: ... } }

photo.image_derivatives.dig(:thumbnail, :small) #=> #<Shrine::UploadedFile ...>
photo.image_derivatives(:thumbnail, :small)     #=> #<Shrine::UploadedFile ...>
photo.image(:thumbnails, :small)                #=> #<Shrine::UploadedFile ...>
```

### Derivative URL

You can retrieve the URL of a derivative URL with `#<name>_url`:

```rb
photo.image_url(:small)  #=> "https://example.com/small.jpg"
photo.image_url(:medium) #=> "https://example.com/medium.jpg"
photo.image_url(:large)  #=> "https://example.com/large.jpg"
```

For nested derivatives you can pass multiple keys:

```rb
photo.image_derivatives #=> { thumbnail: { small: ..., medium: ..., large: ... } }

photo.image_url(:thumbnail, :medium) #=> "https://example.com/medium.jpg"
```

By default, `#<name>_url` method will return `nil` if derivative is not found.
You can use the [`default_url`][default_url] plugin to set up URL fallbacks:

```rb
Attacher.default_url do |derivative: nil, **|
  "/fallbacks/#{derivative}.jpg" if derivative
end
```
```rb
photo.image_url(:medium) #=> "https://example.com/fallbacks.com/medium.jpg"
```

Any additional URL options passed to `#<name>_url` will be forwarded to the
storage:

```rb
photo.image_url(:small, response_content_disposition: "attachment")
```

You can also retrieve the derivative URL via `UploadedFile#url`:

```rb
photo.image_derivatives[:large].url
```

## Attacher API

The derivatives API is primarily defined on the `Shrine::Attacher` class, with
some important methods also being exposed through the `Shrine::Attachment`
module.

Here is a model example with equivalent attacher code:

```rb
photo.image_derivatives!(:thumbnails)
photo.image_derivatives #=> { ... }

photo.image_url(:large) #=> "https://..."
photo.image(:large)     #=> #<Shrine::UploadedFile ...>
```
```rb
attacher.create_derivatives(:thumbnails)
attacher.get_derivatives #=> { ... }

attacher.url(:large) #=> "https://..."
attacher.get(:large) #=> "#<Shrine::UploadedFile>"
```

## Creating derivatives

By default, the `Attacher#create_derivatives` method downloads the attached
file, calls the processor, uploads results to attacher's permanent storage, and
saves uploaded files on the attacher.

```rb
attacher.file               #=> #<Shrine::UploadedFile id="original.jpg" storage=:store ...>
attacher.create_derivatives # calls default processor and uploads results
attacher.derivatives        #=>
# {
#   small:  #<Shrine::UploadedFile id="small.jpg" storage=:store ...>,
#   medium: #<Shrine::UploadedFile id="medium.jpg" storage=:store ...>,
#   large:  #<Shrine::UploadedFile id="large.jpg" storage=:store ...>,
# }
```

Any additional arguments are forwarded to
[`Attacher#process_derivatives`](#processing-derivatives):

```rb
attacher.create_derivatives(different_source) # pass a different source file
attacher.create_derivatives(foo: "bar")       # pass custom options to the processor
```

### Naming processors

If you want to have multiple processors for an uploader, you can assign each
processor a name:

```rb
class ImageUploader < Shrine
  Attacher.derivatives :thumbnails do |original|
    { large: ..., medium: ..., small: ... }
  end

  Attacher.derivatives :crop do |original|
    { cropped: ... }
  end
end
```

Then when creating derivatives you can specify the name of the desired
processor. New derivatives will be merged with any existing ones.

```rb
attacher.create_derivatives(:thumbnails)
attacher.derivatives #=> { large: ..., medium: ..., small: ... }

attacher.create_derivatives(:crop)
attacher.derivatives #=> { large: ..., medium: ..., small: ..., cropped: ... }
```

### Derivatives storage

By default, derivatives are uploaded to the permanent storage of the attacher.
You can change the destination storage by passing `:storage` to the creation
call:

```rb
attacher.create_derivatives(storage: :cache) # will be promoted together with main file
attacher.create_derivatives(storage: :other_store)
```

You can also change the default destination storage with the `:storage` plugin
option:

```rb
plugin :derivatives, storage: :other_store
```

The storage can be dynamic based on the derivative name:

```rb
plugin :derivatives, storage: -> (derivative) do
  if derivative == :thumb
    :thumbnail_store
  else
    :store
  end
end
```

You can also set this option with `Attacher.derivatives_storage`:

```rb
Attacher.derivatives_storage :other_store
# or
Attacher.derivatives_storage do |derivative|
  if derivative == :thumb
    :thumbnail_store
  else
    :store
  end
end
```

The storage block is evaluated in the context of a `Shrine::Attacher` instance:

```rb
Attacher.derivatives_storage do |derivative|
  self   #=> #<Shrine::Attacher>

  record  #=> #<Photo>
  name    #=> :image
  context #=> { ... }
end
```

### Nesting derivatives

Derivatives can be nested to any level, using both hashes and arrays, but the
top-level object must be a hash.

```rb
Attacher.derivatives :tiff do |original|
  {
    thumbnail: {
      small:  small,
      medium: medium,
      large:  large,
    },
    layers: [
      layer_1,
      layer_2,
      # ...
    ]
  }
end
```
```rb
attacher.derivatives #=>
# {
#   thumbnail: {
#     small:  #<Shrine::UploadedFile ...>,
#     medium: #<Shrine::UploadedFile ...>,
#     large:  #<Shrine::UploadedFile ...>,
#   },
#   layers: [
#     #<Shrine::UploadedFile ...>,
#     #<Shrine::UploadedFile ...>,
#     # ...
#   ]
# }
```

## Processing derivatives

A derivatives processor block takes the original file, and is expected to
return a hash of processed files (it can be [nested](#nesting-derivatives)).

```rb
Attacher.derivatives :my_processor do |original|
  # return a hash of processed files
end
```

The `Attacher#create_derivatives` method internally calls
`Attacher#process_derivatives`, which in turn calls the processor:

```rb
files = attacher.process_derivatives(:my_processor)
attacher.add_derivatives(files)
```

### Dynamic processing

The processor block is evaluated in context of the `Shrine::Attacher` instance,
which allows you to change your processing logic based on the record data.

```rb
Attacher.derivatives :my_processor do |original|
  self    #=> #<Shrine::Attacher>

  record  #=> #<Photo>
  name    #=> :image
  context #=> { ... }

  # ...
end
```

Moreover, any options passed to `Attacher#process_derivatives` will be
forwarded to the processor:

```rb
attacher.process_derivatives(:my_processor, foo: "bar")
```
```rb
Attacher.derivatives :my_processor do |original, **options|
  options #=> { :foo => "bar" }
  # ...
end
```

### Source file

By default, the `Attacher#process_derivatives` method will download the
attached file and pass it to the processor:

```rb
Attacher.derivatives :my_processor do |original|
  original #=> #<File:...>
  # ...
end
```
```rb
attacher.process_derivatives(:my_processor) # downloads attached file and passes it to the processor
```

If you want to use a different source file, you can pass it in to the process
call. Typically you'd pass a local file on disk. If you pass a
`Shrine::UploadedFile` object, it will be automatically downloaded to disk.

```rb
# named processor:
attacher.process_derivatives(:my_processor, source_file)

# default processor:
attacher.process_derivatives(source_file)
```

If you want to call multiple processors in a row with the same source file, you
can use this to avoid re-downloading the same source file each time:

```rb
attacher.file.download do |original|
  attacher.process_derivatives(:thumbnails, original)
  attacher.process_derivatives(:colors,     original)
end
```

## Adding derivatives

If you already have processed files that you want to save, you can do that with
`Attacher#add_derivatives`:

```rb
attacher.add_derivatives(
  one: file_1,
  two: file_2,
  # ...
)

attacher.derivatives #=>
# {
#   one: #<Shrine::UploadedFile>,
#   two: #<Shrine::UploadedFile>,
#   ...
# }
```

New derivatives will be merged with existing ones:

```rb
attacher.derivatives #=> { one: #<Shrine::UploadedFile> }
attacher.add_derivatives(two: two_file)
attacher.derivatives #=> { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile> }
```

The merging is deep, so the following will work as well:

```rb
attacher.derivatives #=> { nested: { one: #<Shrine::UploadedFile> } }
attacher.add_derivatives(nested: { two: two_file })
attacher.derivatives #=> { nested: { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile> } }
```

For adding a single derivative, you can also use the singular
`Attacher#add_derivative`:

```rb
attacher.add_derivative(:thumb, thumbnail_file)
```

Any options passed to `Attacher#add_derivative(s)` will be forwarded to
[`Attacher#upload_derivatives`](#uploading-derivatives).

```rb
attacher.add_derivative(:thumb, thumbnail_file, storage: :thumbnails_store)             # specify destination storage
attacher.add_derivative(:thumb, thumbnail_file, upload_options: { acl: "public-read" }) # pass uploader options
```

The `Attacher#add_derivative(s)` methods are thread-safe.

## Uploading derivatives

If you want to upload processed files without setting them, you can use
`Attacher#upload_derivatives`:

```rb
derivatives = attacher.upload_derivatives(
  one: file_1,
  two: file_2,
  # ...
)

derivatives #=>
# {
#   one: #<Shrine::UploadedFile>,
#   two: #<Shrine::UploadedFile>,
#   ...
# }
```

For uploading a single derivative, you can also use the singular
`Attacher#upload_derivative`:

```rb
attacher.upload_derivative(:thumb, thumbnail_file)
#=> #<Shrine::UploadedFile>
```

### Uploader options

You can specify the destination storage by passing `:storage` option to
`Attacher#upload_derivative(s)`. This will override the [default derivatives
storage](#derivatives-storage) setting.

```rb
attacher.upload_derivative(:thumb, thumnbail_file, storage: :other_store)
#=> #<Shrine::UploadedFile @id="thumb.jpg" @storage_key=:other_store ...>
```

Any other options will be forwarded to the uploader:

```rb
attacher.upload_derivative :thumb, thumbnail_file,
  upload_options: { acl: "public-read" },
  metadata: { "foo" => "bar" }),
  location: "path/to/derivative"
```

The `:derivative` name is automatically passed to the uploader:

```rb
class MyUploader < Shrine
  plugin :add_metadata

  add_metadata :md5 do |io, derivative: nil, **|
    calculate_signature(io, :md5) unless derivative
  end

  def generate_location(io, derivative: nil, **)
    "location/for/#{derivative}"
  end

  plugin :upload_options, store: -> (io, derivative: nil, **) {
    { acl: "public-read" } if derivative
  }
end
```

### File deletion

Files given to `Attacher#upload_derivative(s)` are assumed to be temporary, so
for convenience they're automatically closed and unlinked after upload.

If you want to disable this behaviour, pass `delete: false`:

```rb
attacher.upload_derivative(:thumb, thumbnail_file, delete: false)
```

## Merging derivatives

If you want to save already uploaded derivatives, you can use
`Attacher#merge_derivatives`:

```rb
attacher.derivatives #=> { one: #<Shrine::UploadedFile> }
attacher.merge_derivatives attacher.upload_derivatives(two: two_file)
attacher.derivatives #=> { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile> }
```

This does a deep merge, so the following will work as well:

```rb
attacher.derivatives #=> { nested: { one: #<Shrine::UploadedFile> } }
attacher.merge_derivatives attacher.upload_derivatives(nested: { two: two_file })
attacher.derivatives #=> { nested: { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile> } }
```

The `Attacher#merge_derivatives` method is thread-safe.

### Setting derivatives

If instead of adding you want to *override* existing derivatives, you can use
`Attacher#set_derivatives`:

```rb
attacher.derivatives #=> { one: #<Shrine::UploadedFile> }
attacher.set_derivatives attacher.upload_derivatives(two: two_file)
attacher.derivatives #=> { two: #<Shrine::UploadedFile> }
```

If you're using the [`model`][model] plugin, this method will trigger writing
derivatives data into the column attribute.

## Promoting derivatives

Any assigned derivatives that are uploaded to temporary storage will be
automatically uploaded to permanent storage on `Attacher#promote`.

```rb
attacher.derivatives[:one].storage_key #=> :cache
attacher.promote
attacher.derivatives[:one].storage_key #=> :store
```

If you want more control over derivatives promotion, you can use
`Attacher#promote_derivatives`. Any additional options passed to it are
forwarded to the uploader.

```rb
attacher.derivatives[:one].storage_key #=> :cache
attacher.promote_derivatives(upload_options: { acl: "public-read" })
attacher.derivatives[:one].storage_key #=> :store
```

## Removing derivatives

If you want to manually remove certain derivatives, you can do that with
`Attacher#remove_derivative`.

```rb
attacher.derivatives #=> { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile> }
attacher.remove_derivative(:two) #=> #<Shrine::UploadedFile> (removed derivative)
attacher.derivatives #=> { one: #<Shrine::UploadedFile> }
```

You can also use the plural `Attacher#remove_derivatives` for removing multiple
derivatives:

```rb
attacher.derivatives #=> { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile>, three: #<Shrine::UploadedFile> }
attacher.remove_derivative(:two, :three) #=> [#<Shrine::UploadedFile>, #<Shrine::UploadedFile>] (removed derivatives)
attacher.derivatives #=> { one: #<Shrine::UploadedFile> }
```

It's possible to remove nested derivatives as well:

```rb
attacher.derivatives #=> { nested: { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile> } }
attacher.remove_derivative([:nested, :one]) #=> #<Shrine::UploadedFile> (removed derivative)
attacher.derivatives #=> { nested: { one: #<Shrine::UploadedFile> } }
```

The removed derivatives are not automatically deleted, because it's safer to
first persist the removal change, and only then perform the deletion.

```rb
derivative = attacher.remove_derivative(:two)
# ... persist removal change ...
derivative.delete
```

If you still want to delete the derivative at the time of removal, you can
pass `delete: true`:

```rb
derivative = attacher.remove_derivative(:two, delete: true)
derivative.exists? #=> false
```

### Deleting derivatives

If you want to delete a collection of derivatives, you can use
`Attacher#delete_derivatives`:

```rb
derivatives #=> { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile> }

attacher.delete_derivatives(derivatives)

derivatives[:one].exists? #=> false
derivatives[:two].exists? #=> false
```

Without arguments `Attacher#delete_derivatives` deletes current derivatives:

```rb
attacher.derivatives #=> { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile> }

attacher.delete_derivatives

attacher.derivatives[:one].exists? #=> false
attacher.derivatives[:two].exists? #=> false
```

Derivatives are automatically deleted on `Attacher#destroy`.

## Miscellaneous

### Without original

You can store derivatives even if there is no main attached file:

```rb
attacher.file #=> nil
attacher.add_derivatives(one: one_file, two: two_file)
attacher.data #=>
# {
#   "derivatives" => {
#     "one" => { "id" => "...", "storage" => "...", "metadata": { ... } },
#     "two" => { "id" => "...", "storage" => "...", "metadata": { ... } },
#   }
# }
```

However, note that in this case operations such as promotion and deletion will
not be automatically triggered in the attachment flow, you'd need to trigger
them manually as needed.

### Iterating derivatives

If you want to iterate over a nested hash of derivatives (which can be
`Shrine::UploadedFile` objects or raw files), you can use
`Attacher#map_derivative` or `Shrine.map_derivative`:

```rb
derivatives #=>
# {
#   one: #<Shrine::UploadedFile>,
#   two: { three: #<Shrine::UploadedFile> },
#   four: [#<Shrine::UploadedFile>],
# }

# or Shrine.map_derivative
attacher.map_derivative(derivatives) do |name, file|
  puts "#{name}, #{file}"
end

# output:
#
#   :one, #<Shrine::UploadedFile>
#   [:two, :three], #<Shrine::UploadedFile>
#   [:four, 0], #<Shrine::UploadedFile>
```

### Parsing derivatives

If you want to directly parse derivatives data written to a record attribute,
you can use `Shrine.derivatives` (counterpart to `Shrine.uploaded_file`):

```rb
# or MyUploader.derivatives
derivatives = Shrine.derivatives({
  "one" => { "id" => "...", "storage" => "...", "metadata" => { ... } },
  "two" => { "three" => { "id" => "...", "storage" => "...", "metadata" => { ... } } }
  "four" => [{ "id" => "...", "storage" => "...", "metadata" => { ... } }]
})

derivatives #=>
# {
#   one: #<Shrine::UploadedFile>,
#   two: { three: #<Shrine::UploadedFile> },
#   four: [#<Shrine::UploadedFile>],
# }
```

Like `Shrine.uploaded_file`, the `Shrine.derivatives` method accepts data as a
hash (stringified or symbolized) or a JSON string.

## Instrumentation

If the `instrumentation` plugin has been loaded, the `derivatives` plugin adds
instrumentation around derivatives processing.

```rb
# instrumentation plugin needs to be loaded *before* derivatives
plugin :instrumentation
plugin :derivatives
```

Processing derivatives will trigger a `derivatives.shrine` event with the
following payload:

| Key                  | Description                            |
| :--                  | :----                                  |
| `:processor`         | Name of the derivatives processor      |
| `:processor_options` | Any options passed to the processor    |
| `:uploader`          | The uploader class that sent the event |

A default log subscriber is added as well which logs these events:

```
Derivatives (2133ms) – {:processor=>:thumbnails, :processor_options=>{}, :uploader=>ImageUploader}
```

You can also use your own log subscriber:

```rb
plugin :derivatives, log_subscriber: -> (event) {
  Shrine.logger.info JSON.generate(name: event.name, duration: event.duration, **event.payload)
}
```
```
{"name":"derivatives","duration":2133,"processor":"thumbnails","processor_options":{},"uploader":"ImageUploader"}
```

Or disable logging altogether:

```rb
plugin :derivatives, log_subscriber: nil
```

[default_url]: https://shrinerb.com/docs/plugins/default_url
[entity]: https://shrinerb.com/docs/plugins/entity
[model]: https://shrinerb.com/docs/plugins/model
