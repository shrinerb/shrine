---
title: Add Metadata
---

The [`add_metadata`][add_metadata] plugin allows adding custom metadata to
uploaded files.

```rb
Shrine.plugin :add_metadata
```

## Metadata block

The `Shrine.add_metadata` method allows you to register a block that will get
executed on upload, where you can return custom metadata:

```rb
require "pdf-reader" # https://github.com/yob/pdf-reader

class PdfUploader < Shrine
  add_metadata :page_count do |io|
    reader = PDF::Reader.new(io)
    reader.page_count
  end
end
```

The above will add `page_count` key to the metadata hash, and also create the
`#page_count` reader method on the `Shrine::UploadedFile`.

```rb
uploaded_file.metadata["page_count"] #=> 30
# or
uploaded_file.page_count #=> 30
```

By default, if your block returns `nil` then the `nil` value will be stored into
metadata. If you do not want to store anything when your block returns nil, you
can use the `skip_nil: true` option:

```rb
class PdfUploader < Shrine
  add_metadata :pages, skip_nil: true do |io|
    if is_pdf?(io)
      reader = PDF::Reader.new(io)
      reader.page_count
    else
      # If this is not a PDF, then the pages metadata will not be stored
      nil
    end
  end
end
```

### Multiple values

You can also extract multiple metadata values at once, by using `add_metadata`
without an argument and returning a hash of metadata.

```rb
require "exif" # https://github.com/tonytonyjan/exif

class ImageUploader < Shrine
  add_metadata do |io|
    begin
      data = Exif::Data.new(io)
    rescue Exif::NotReadable # not a valid image
      next {}
    end

    { "date_time"     => data.date_time,
      "flash"         => data.flash,
      "focal_length"  => data.focal_length,
      "exposure_time" => data.exposure_time }
  end
end
```
```rb
uploaded_file.metadata #=>
# {
#   ...
#   "date_time" => "2019:07:20 16:16:08",
#   "flash" => 16,
#   "focal_length" => 26/1,
#   "exposure_time" => 1/500,
# }
```

In this case Shrine won't automatically create reader methods for the extracted
metadata, but you can create them via `Shrine.metadata_method`:

```rb
class ImageUploader < Shrine
  # ...
  metadata_method :date_time, :flash
end
```
```rb
uploaded_file.date_time #=> "2019:07:20 16:16:08"
uploaded_file.flash     #=> 16
```

### Ensuring file

The `io` might not always be a file object, so if you're using an analyzer
which requires the source file to be on disk, you can use `Shrine.with_file` to
ensure you have a file object.

```rb
require "streamio-ffmpeg" # https://github.com/streamio/streamio-ffmpeg

class VideoUploader < Shrine
  add_metadata do |io|
    movie = Shrine.with_file(io) do |file|
      FFMPEG::Movie.new(file.path)
    end

    { "duration"   => movie.duration,
      "bitrate"    => movie.bitrate,
      "resolution" => movie.resolution,
      "frame_rate" => movie.frame_rate }
  end
end
```

### Uploader options

Uploader options are also yielded to the block, you can access them for more
context:

```rb
add_metadata do |io, **options|
  options #=>
  # {
  #   record:   #<Photo>,
  #   name:     :image,
  #   action:   :store,
  #   metadata: { ... },
  #   ...
  # }
end
```

#### Metadata

The `:metadata` option holds metadata that was extracted so far:

```rb
add_metadata :foo do |io, metadata:, **|
  metadata #=>
  # {
  #   "size"      => 239823,
  #   "filename"  => "nature.jpg",
  #   "mime_type" => "image/jpeg"
  # }

  "foo"
end

add_metadata :bar do |io, metadata:, **|
  metadata #=>
  # {
  #   "size"      => 239823,
  #   "filename"  => "nature.jpg",
  #   "mime_type" => "image/jpeg",
  #   "foo"       => "foo"
  # }

  "bar"
end
```

## Updating metadata

If you just wish to add some custom metadata to existing uploads, you can do it
with `UploadedFile#add_metadata` (and write the changes back to the model):

```rb
attacher.file.add_metadata("foo" => "bar")
attacher.write # write changes to the model attribute

attacher.file.metadata #=> { ..., "foo" => "bar" }
```

You can also use the `Attacher#add_metadata` shorthand, which also takes care
of syncing the model:

```rb
attacher.add_metadata("foo" => "bar")

attacher.file.metadata #=> { ..., "foo" => "bar" }
```

[add_metadata]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/add_metadata.rb
