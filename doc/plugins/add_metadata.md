# Add Metadata

The [`add_metadata`][add_metadata] plugin provides a convenient method for
extracting and adding custom metadata values.

```rb
plugin :add_metadata

add_metadata :exif do |io|
  begin
    Exif::Data.new(io).to_h
  rescue Exif::NotReadable # not a valid image
    {}
  end
end
```

The above will add "exif" to the metadata hash, and also create the `#exif`
reader method on `Shrine::UploadedFile`.

```rb
image.metadata["exif"]
# or
image.exif
```

## Multiple values

You can also extract multiple metadata values at once, by using `add_metadata`
without an argument and returning a hash of metadata.

```rb
add_metadata do |io|
  begin
    data = Exif::Data.new(io)
  rescue Exif::NotReadable # not a valid image
    next {}
  end

  { date_time:     data.date_time,
    flash:         data.flash,
    focal_length:  data.focal_length,
    exposure_time: data.exposure_time }
end
```

In this case Shrine won't automatically create reader methods for the extracted
metadata on Shrine::UploadedFile, but you can create them via
`#metadata_method`.

```rb
metadata_method :date_time, :flash
```

## Ensuring file

The `io` might not always be a file object, so if you're using an analyzer
which requires the source file to be on disk, you can use `Shrine.with_file` to
ensure you have a file object.

```rb
add_metadata do |io|
  movie = Shrine.with_file(io) { |file| FFMPEG::Movie.new(file.path) }

  { "duration"   => movie.duration,
    "bitrate"    => movie.bitrate,
    "resolution" => movie.resolution,
    "frame_rate" => movie.frame_rate }
end
```

## Uploader options

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

[add_metadata]: /lib/shrine/plugins/add_metadata.rb
