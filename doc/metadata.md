---
title: Extracting Metadata
---

Before a file is uploaded, Shrine automatically extracts metadata from it, and
stores them in the `Shrine::UploadedFile` object.

```rb
uploaded_file = uploader.upload(file)
uploaded_file.metadata #=>
# {
#   "size" => 345993,
#   "filename" => "matrix.mp4",
#   "mime_type" => "video/mp4",
# }
```

Under the hood, `Shrine#upload` calls `Shrine#extract_metadata`, which you can
also use directly to extract metadata from any IO object:

```rb
uploader.extract_metadata(io) #=>
# {
#   "size" => 345993,
#   "filename" => "matrix.mp4",
#   "mime_type" => "video/mp4",
# }
```

The following metadata is extracted by default:

| Key         | Default source                                     |
| :-----      | :------                                            |
| `filename`  | extracted from `io.original_filename` or `io.path` |
| `mime_type` | extracted from `io.content_type`                   |
| `size`      | extracted from `io.size`                           |

## Accessing metadata

You can access the stored metadata in three ways:

```rb
# via methods (if they're defined)
uploaded_file.size
uploaded_file.original_filename
uploaded_file.mime_type

# via the metadata hash
uploaded_file.metadata["size"]
uploaded_file.metadata["filename"]
uploaded_file.metadata["mime_type"]

# via the #[] operator
uploaded_file["size"]
uploaded_file["filename"]
uploaded_file["mime_type"]
```

## Controlling extraction

`Shrine#upload` accepts a `:metadata` option which accepts the following values:

  * `Hash` – adds/overrides extracted metadata with the given hash

    ```rb
    uploaded_file = uploader.upload(file, metadata: { "filename" => "Matrix[1999].mp4", "foo" => "bar" })
    uploaded_file.original_filename #=> "Matrix[1999].mp4"
    uploaded_file.metadata["foo"]   #=> "bar"
    ```

  * `false` – skips metadata extraction (useful in tests)

    ```rb
    uploaded_file = uploader.upload(file, metadata: false)
    uploaded_file.metadata #=> {}
    ```

  * `true` – forces metadata extraction when a `Shrine::UploadedFile` is being
    uploaded (by default metadata is simply copied over)

    ```rb
    uploaded_file = uploader.upload(uploaded_file, metadata: true)
    uploaded_file.metadata # re-extracted metadata
    ```

## MIME type

By default, the `mime_type` metadata will be copied over from the
`#content_type` attribute of the input file (if present). However, since
`#content_type` value comes from the `Content-Type` header of the upload
request, it's *not guaranteed* to hold the actual MIME type of the file (browser
determines this header based on file extension).

Moreover, only `ActionDispatch::Http::UploadedFile`, `Shrine::RackFile`, and
`Shrine::DataFile` objects have `#content_type` defined, so when uploading
objects such as `File`, the `mime_type` value will be nil by default.

To remedy that, Shrine comes with a
[`determine_mime_type`][determine_mime_type] plugin which is able to extract
the MIME type from IO *content*:

```rb
# Gemfile
gem "marcel", "~> 0.3"
```
```rb
Shrine.plugin :determine_mime_type, analyzer: :marcel
```
```rb
uploaded_file = uploader.upload StringIO.new("<?php ... ?>")
uploaded_file.mime_type #=> "application/x-php"
```

You can choose different analyzers, and even mix-and-match them. See the
[`determine_mime_type`][determine_mime_type] plugin docs for more details.

## Image Dimensions

Shrine comes with a [`store_dimensions`][store_dimensions] plugin for
extracting image dimensions. It adds `width` and `height` metadata values, and
also adds `#width`, `#height`, and `#dimensions` methods to the
`Shrine::UploadedFile` object.

```rb
# Gemfile
gem "fastimage" # default analyzer
```
```rb
Shrine.plugin :store_dimensions
```
```rb
uploaded_file = uploader.upload(image)
uploaded_file.metadata["width"]  #=> 1600
uploaded_file.metadata["height"] #=> 900

# convenience methods
uploaded_file.width      #=> 1600
uploaded_file.height     #=> 900
uploaded_file.dimensions #=> [1600, 900]
```

By default, the plugin uses [FastImage] to analyze dimensions, but you can also
have it use [MiniMagick] or [ruby-vips]. See the
[`store_dimensions`][store_dimensions] plugin docs for more details.

## Custom metadata

In addition to the built-in metadata, Shrine allows you to extract and store
any custom metadata, using the [`add_metadata`][add_metadata] plugin (which
internally extends `Shrine#extract_metadata`).

For example, you might want to extract EXIF data from images:

```rb
# Gemfile
gem "exiftool"
```
```rb
require "exiftool"

class ImageUploader < Shrine
  plugin :add_metadata

  add_metadata :exif do |io, context|
    Shrine.with_file(io) do |file|
      Exiftool.new(file.path).to_hash
    end
  end
end
```
```rb
uploaded_file = uploader.upload(image)
uploaded_file.metadata["exif"] #=> {...}
uploaded_file.exif             #=> {...}
```

Or, if you're uploading videos, you might want to extract some video-specific
meatadata:

```rb
# Gemfile
gem "streamio-ffmpeg"
```
```rb
require "streamio-ffmpeg"

class VideoUploader < Shrine
  plugin :add_metadata

  add_metadata do |io, context|
    movie = Shrine.with_file(io) { |file| FFMPEG::Movie.new(file.path) }

    { "duration"   => movie.duration,
      "bitrate"    => movie.bitrate,
      "resolution" => movie.resolution,
      "frame_rate" => movie.frame_rate }
  end
end
```
```rb
uploaded_file = uploader.upload(video)
uploaded_file.metadata #=>
# {
#   ...
#   "duration" => 7.5,
#   "bitrate" => 481,
#   "resolution" => "640x480",
#   "frame_rate" => 16.72
# }
```

The yielded `io` object will not always be an object that responds to `#path`.
For example, with the `data_uri` plugin the `io` can be a `StringIO` wrapper,
while with `restore_cached_data` or `refresh_metadata` plugins the `io` might
be a `Shrine::UploadedFile` object. So, we're using `Shrine.with_file` to
ensure we have a file object.

### Adding metadata

If you wish to add metadata to an already attached file, you can do it as
follows:

```rb
photo.image_attacher.add_metadata("foo" => "bar")
photo.image.metadata #=> { ..., "foo" => "bar" }
photo.save # persist changes
```

## Metadata columns

If you want to write any of the metadata values into a separate database column
on the record, you can use the `metadata_attributes` plugin.

```rb
Shrine.plugin :metadata_attributes, :mime_type => :type
```
```rb
photo = Photo.new(image: file)
photo.image_type #=> "image/jpeg"
```

## Direct uploads

When attaching files that were uploaded directly to the cloud or a [tus
server], Shrine won't automatically extract metadata from them, instead it will
copy any existing metadata that was set on the client side. The reason why this
is the default behaviour is because metadata extraction requires (at least
partially) retrieving file content from the storage, which could potentially be
expensive depending on the storage and the type of metadata being extracted.

```rb
# no additional metadata will be extracted in this assignment by default
photo.image = '{"id":"9e6581a4ea1.jpg","storage":"cache","metadata":{...}}'
```

### Extracting on attachment

If you want metadata to be automatically extracted on assignment (which is
useful if you want to validate the extracted metadata or have it immediately
available for any other reason), you can load the `restore_cached_data` plugin:

```rb
Shrine.plugin :restore_cached_data # automatically extract metadata from cached files on assignment
```
```rb
photo.image = '{"id":"ks9elsd.jpg","storage":"cache","metadata":{}}' # metadata is extracted
photo.image.metadata #=>
# {
#   "size" => 4593484,
#   "filename" => "nature.jpg",
#   "mime_type" => "image/jpeg"
# }
```

### Extracting in the background

#### A) Extracting with promotion

If you're using [backgrounding], you can extract metadata during background
promotion using the `refresh_metadata` plugin (which the `restore_cached_data`
plugin uses internally):

```rb
Shrine.plugin :refresh_metadata # allow re-extracting metadata
Shrine.plugin :backgrounding

Shrine::Attacher.promote_block do
  PromoteJob.perform_async(self.class.name, record.class.name, record.id, name, file_data)
end
```
```rb
class PromoteJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.refresh_metadata! # extract metadata
    attacher.atomic_promote
  end
end
```

#### B) Extracting separately from promotion

You can also extract metadata in the background separately from promotion:

```rb
MetadataJob.perform_async(
  attacher.class.name,
  attacher.record.class.name,
  attacher.record.id,
  attacher.name,
  attacher.file_data,
)
```
```rb
class MetadataJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.refresh_metadata!
    attacher.atomic_persist
  end
end
```

### Combining foreground and background

If you have some metadata that you want to extract in the foreground and some
that you want to extract in the background, you can use the uploader context:

```rb
class VideoUploader < Shrine
  plugin :add_metadata

  add_metadata do |io, **options|
    next unless options[:background] # proceed only when `background: true` was specified

    # example of metadata extraction
    movie = Shrine.with_file(io) { |file| FFMPEG::Movie.new(file.path) }

    { "duration"   => movie.duration,
      "bitrate"    => movie.bitrate,
      "resolution" => movie.resolution,
      "frame_rate" => movie.frame_rate }
  end
end
```
```rb
class PromoteJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.refresh_metadata!(background: true) # specify the flag
    attacher.atomic_promote
  end
end
```

Now triggering metadata extraction in the controller on attachment (using
`restore_cached_data` or `refresh_metadata` plugin) will skip the video
metadata block, which will be triggered later in the background job.

### Optimizations

If you want to do both metadata extraction and file processing during
promotion, you can wrap both in an `UploadedFile#open` block to make
sure the file content is retrieved from the storage only once.

```rb
class PromoteJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)

    attacher.file.open do
      attacher.refresh_metadata!
      attacher.create_derivatives
    end

    attacher.atomic_promote
  end
end
```

If you're dealing with large files and have metadata extractors that use
`Shrine.with_file`, you might want to use the `tempfile` plugin to make sure
the same copy of the uploaded file is reused for both metadata extraction and
file processing.

```rb
Shrine.plugin :tempfile # load it globally so that it overrides `Shrine.with_file`
```
```rb
# ...
attacher.file.open do
  attacher.refresh_metadata!
  attacher.create_derivatives(attacher.file.tempfile)
end
# ...
```

[`file`]: http://linux.die.net/man/1/file
[MimeMagic]: https://github.com/minad/mimemagic
[Marcel]: https://github.com/basecamp/marcel
[FastImage]: https://github.com/sdsykes/fastimage
[MiniMagick]: https://github.com/minimagick/minimagick
[ruby-vips]: https://github.com/libvips/ruby-vips
[tus server]: https://github.com/janko/tus-ruby-server
[determine_mime_type]: https://shrinerb.com/docs/plugins/determine_mime_type
[store_dimensions]: https://shrinerb.com/docs/plugins/store_dimensions
[add_metadata]: https://shrinerb.com/docs/plugins/add_metadata
[backgrounding]: https://shrinerb.com/docs/plugins/backgrounding
