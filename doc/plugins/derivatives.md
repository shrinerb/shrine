# Derivatives

The derivatives plugin allows storing processed files ("derivatives") alongside
the main attached file. The processed file data will be saved together with the
main attachment data in the same record attribute.

```rb
plugin :derivatives
```

## Contents

* [Creating derivatives](#creating-derivatives)
  - [Nesting derivatives](#nesting-derivatives)
* [Retrieving derivatives](#retrieving-derivatives)
* [Derivative URL](#derivative-url)
* [Processing derivatives](#processing-derivatives)
  - [Dynamic processing](#dynamic-processing)
  - [Source file](#source-file)
* [Adding derivatives](#adding-derivatives)
  - [Derivatives storage](#derivatives-storage)
  - [Uploading derivatives](#uploading-derivatives)
    - [Upload options](#upload-options)
    - [File deletion](#file-deletion)
  - [Setting derivatives](#setting-derivatives)
  - [Promoting derivatives](#promoting-derivatives)
* [Removing derivatives](#removing-derivatives)
* [Without original](#without-original)
* [Iterating derivatives](#iterating-derivatives)
* [Parsing derivatives](#parsing-derivatives)
* [Instrumentation](#instrumentation)

## Creating derivatives

When you have a file attached, you can generate derivatives from it and save
them alongside the attached file. The simplest way to do this is to define a
processor which will return processed files, and then call it with
`Attacher#add_derivatives` when you want to generate the derivatives. Here is
an example of generating image thumbnails:

```rb
# Gemfile
gem "image_processing", "~> 1.2"
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :derivatives

  Attacher.derivatives_processor :thumbnails do |original|
    processor = ImageProcessing::MiniMagick.source(original)

    {
      small:  processor.resize_to_limit!(300, 300),
      medium: processor.resize_to_limit!(500, 500),
      large:  processor.resize_to_limit!(800, 800),
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
photo.image #=> #<Shrine::UploadedFile>
photo.image_derivatives #=> {}

photo.image_attacher.add_derivatives(:thumbnails) # calls processor and uploads results
photo.image_derivatives #=>
# {
#   small:  #<Shrine::UploadedFile>,
#   medium: #<Shrine::UploadedFile>,
#   large:  #<Shrine::UploadedFile>,
# }
```

The derivatives data is stored in the `#<name>_data` record attribute alongside
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

### Nesting derivatives

Derivatives can be nested to any level, using both hashes and arrays, but the
top-level object must be a hash.

```rb
Attacher.derivatives_processor :tiff do |original|
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

## Retrieving derivatives

If you're using the `Shrine::Attachment` module, you can retrieve stored
derivatives by calling `#<name>_derivatives` on your model/entity.

```rb
class Photo < Model(:image_data)
  include ImageUploader::Attachment(:image)
end
```
```rb
photo.image_derivatives #=>
# {
#   small:  #<Shrine::UploadedFile>,
#   medium: #<Shrine::UploadedFile>,
#   large:  #<Shrine::UploadedFile>,
# }
```

A specific derivative can be retrieved in any of the following ways:

```rb
photo.image_derivatives[:small] #=> #<Shrine::UploadedFile>
photo.image_derivatives(:small) #=> #<Shrine::UploadedFile>
photo.image(:small)             #=> #<Shrine::UploadedFile>
```

And with nested derivatives:

```rb
photo.image_derivatives #=> { thumbnail: { small: ..., medium: ..., large: ... } }

photo.image_derivatives.dig(:thumbnail, :small) #=> #<Shrine::UploadedFile>
photo.image_derivatives(:thumbnail, :small)     #=> #<Shrine::UploadedFile>
photo.image(:thumbnails :small)                 #=> #<Shrine::UploadedFile>
```

When using `Shrine::Attacher` directly, you can retrieve derivatives using
`Attacher#derivatives`:

```rb
attacher.derivatives #=>
# {
#   small:  #<Shrine::UploadedFile>,
#   medium: #<Shrine::UploadedFile>,
#   large:  #<Shrine::UploadedFile>,
# }
```

## Derivative URL

If you're using the `Shrine::Attachment` module, you can use the `#<name>_url`
method to retrieve the URL of a derivative.

```rb
class Photo < Model(:image_data)
  include ImageUploader::Attachment(:image)
end
```
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
Attacher.default_url do |derivative:, **|
  "https://fallbacks.com/#{derivative}.jpg"
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
# or
attacher.derivatives[:large].url
```

## Processing derivatives

When you've defined a derivatives processor, you can pass the processor name to
`Attacher#add_derivatives` or `Attacher#upload_derivatives` to call the
processor and upload processed files.

```rb
Attacher.derivatives_processor :thumbnails do |original|
  # ...
end
```
```rb
attacher.add_derivatives(:thumbnails)
```

If you want to separate processing from uploading, you can call
`Attacher#process_derivatives` directly:

```rb
files = attacher.process_derivatives(:thumbnails)

attacher.add_derivatives(files)
```

### Dynamic processing

The processor block is evaluated in context of the `Shrine::Attacher` instance,
which allows you to change your processing logic based on the record data.

```rb
Attacher.derivatives_processor :thumbnails do |original|
  self    #=> #<Shrine::Attacher>

  record  #=> #<Photo>
  name    #=> :image
  context #=> { ... }

  # ...
end
```

You can also pass additional options to the processor via
`Attacher#process_derivatives`:

```rb
Attacher.derivatives_processor :thumbnails do |original, **options|
  options #=> { :foo => "bar" }
  # ...
end
```
```rb
attacher.process_derivatives(:thumbnails, foo: "bar")
```

### Source file

By default, on `Attacher#add_derivatives` and `Attacher#upload_derivatives`,
attached file will be automatically downloaded and passed to the processor.

```rb
Attacher.derivatives_processor :thumbnails do |original|
  original #=> #<File:...>
  # ...
end
```
```rb
attacher.process_derivatives(:thumbnails)
```

If you already have the source file locally, or if you're calling multiple
derivatives processors in a row, you can pass the source file as the second
argument:

```rb
# this way the source file is downloaded only once
attacher.file.download do |original|
  attacher.process_derivatives(:thumbnails, original)
  attacher.process_derivatives(:colors,     original)
end
```

## Adding derivatives

Passing the processor name to `Attacher#add_derivatives` is just a convenience
layer, you can also pass processed files directly:

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

You can also add a single derivative:

```rb
attacher.add_derivative(:thumb, thumbnail_file)
```

Added derivatives will be merged with existing ones:

```rb
attacher.derivatives #=> { one: #<Shrine::UploadedFile> }
attacher.add_derivative(:two, two_file)
attacher.derivatives #=> { one: #<Shrine::UploadedFile>, two: #<Shrine::UploadedFile> }
```

Note that this does a shallow merge. If you need to do deep merging, see the
[Setting derivatives](#setting-derivatives) section.

Any options passed to `Attacher#add_derivative(s)` will be forwarded to
`Attacher#upload_derivatives`.

```rb
attacher.add_derivative(:thumb, thumbnail_file, storage: :thumbnails_store)
```

The `Attacher#add_derivative(s)` methods are thread-safe.

### Derivatives storage

By default, derivatives are uploaded to the permanent storage of the attacher
(`:store` by default). You can choose to have derivatives uploaded to a
different storage via the `:storage` plugin option:

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

### Uploading derivatives

The `Attacher#add_derivative(s)` method internally calls
`Attacher#upload_derivatives` to upload given files. This method can be used
directly:

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

For uploading a single file you can use `Attacher#upload_derivative`:

```rb
attacher.upload_derivative(:thumb, thumbnail_file)
#=> #<Shrine::UploadedFile>
```

#### Upload options

You can use the `:storage` option to upload to a different storage (this
overrides the `:storage` plugin option):

```rb
attacher.upload_derivative(:thumb, thumbnail_file, storage: :other_store)
```

Any additional options are forwarded to the uploader:

```rb
attacher.upload_derivative(:thumb, thumbnail_file, upload_options: { acl: "public-read" })
```

A `:derivative` option is automatically passed to the uploader and holds the
name of the derivative. This means derivative name will be available when using
plugins such as `add_metadata` and `upload_options`.

#### File deletion

Files given to `Attacher#upload_derivative(s)` are assumed to be temporary, so
for convenience they're automatically unlinked after the upload.

If you want to disable this behaviour, pass `delete: false`:

```rb
attacher.upload_derivative(:thumb, thumbnail_file, delete: false)

File.exist?(thumbnail_file.path) #=> true
```

### Setting derivatives

The `Attacher#set_derivatives` method can be used for assigning a collection of
`Shrine::UploadedFile` objects (e.g. coming from `Attacher#upload_derivatives`):

```rb
derivatives #=>
# {
#   one: #<Shrine::UploadedFile>,
#   two: #<Shrine::UploadedFile>,
#   ...
# }

attacher.set_derivatives { derivatives }

attacher.derivatives #=>
# {
#   one: #<Shrine::UploadedFile>,
#   two: #<Shrine::UploadedFile>,
#   ...
# }
```

The reason why `Attacher#set_derivatives` takes a block is thread-safety – the
execution of the given block is wrapped in a mutex.

Current derivatives are yielded to the block, which is useful if you want to
merge new derivatives with existing ones. This can be used if you wanted to use
`Attacher#add_derivatives`, but want to do deep merging.

```rb
attacher.derivatives
#=> { thumbnail: { small: #<Shrine::UploadedFile> } }

new_derivatives = attacher.upload_derivatives(thumbnail: { large: large_file })

attacher.set_derivatives do |derivatives|
  derivatives.merge(new_derivatives) { |key, v1, v2| v1.merge(v2) }
end

attacher.derivatives
#=> { thumbnail: { small: #<Shrine::UploadedFile>, large: #<Shrine::UploadedFile> } }
```

If you're using the [`model`][model] plugin, this method will write derivatives
data into the column attribute.

### Promoting derivatives

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
`Attacher#remove_derivative(s)`. The removed derivatives are not automatically
deleted, because it's safer to first persist the removal change, and only then
perform the deletion.

```rb
attacher.derivatives #=> { gray: #<Shrine::UploadedFile>, thumb: #<Shrine::UploadedFile> }

removed_derivative = attacher.remove_derivative(:gray)
attacher.derivatives #=> { thumb: #<Shrine::UploadedFile> }

# ... persist removal change ...

removed_derivative.delete
```

If you're removing a collection of derivatives, you can delete them using
`Attacher#delete_derivatives`:

```rb
attacher.derivatives #=> { thumbnail: { ... }, other: { ... } }

removed_derivatives = attacher.remove_derivatives(:thumbnail)
attacher.derivatives #=> { other: { ... } }

# ... persist removal change ...

attacher.delete_derivatives(removed_derivatives)
```

Derivatives will be automatically deleted on `Attacher#destroy`.

## Without original

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

## Iterating derivatives

If you want to iterate over a nested hash of derivatives (which can be
`Shrine::UploadedFile` objects or raw files), you can use
`Shrine.map_derivative`:

```rb
derivatives #=>
# {
#   one: #<Shrine::UploadedFile>,
#   two: { three: #<Shrine::UploadedFile> },
#   four: [#<Shrine::UploadedFile>],
# }

# or MyUploader.map_derivative
Shrine.map_derivative(derivatives) do |name, file|
  puts "#{name}, #{file}"
end

# output:
#
#   :one, #<Shrine::UploadedFile>
#   [:two, :three], #<Shrine::UploadedFile>
#   [:four, 0], #<Shrine::UploadedFile>
```

## Parsing derivatives

If you want to directly parse derivatives data written to a record attribute,
you can use `Shrine.derivatives` (which is meant as the counterpart to
`Shrine.uploaded_file`):

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

The `Shrine.derivatives` method accepts data as a hash (stringified or
symbolized) or a JSON string.

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

[default_url]: /doc/plugins/default_url.md#readme
[entity]: /doc/plugins/entity.md#readme
[model]: /doc/plugins/model.md#readme
