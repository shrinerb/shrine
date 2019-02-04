# Add Metadata

The `add_metadata` plugin provides a convenient method for extracting and
adding custom metadata values.

```rb
plugin :add_metadata

add_metadata :exif do |io, context|
  begin
    Exif::Data.new(io).to_h
  rescue Exif::NotReadable # not a valid image
    {}
  end
end
```

The above will add "exif" to the metadata hash, and also create the `#exif`
reader method on Shrine::UploadedFile.

```rb
image.metadata["exif"]
# or
image.exif
```

You can also extract multiple metadata values at once, by using `add_metadata`
without an argument and returning a hash of metadata.

```rb
add_metadata do |io, context|
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

The `io` might not always be a file object, so if you're using an analyzer
which requires the source file to be on disk, you can use `Shrine.with_file` to
ensure you have a file object.

```rb
add_metadata do |io, context|
  movie = Shrine.with_file(io) { |file| FFMPEG::Movie.new(file.path) }

  { "duration"   => movie.duration,
    "bitrate"    => movie.bitrate,
    "resolution" => movie.resolution,
    "frame_rate" => movie.frame_rate }
end
```

Any previously extracted metadata can be accessed via `context[:metadata]`:

```rb
add_metadata :foo do |io, context|
  context[:metadata] #=>
  # {
  #   "size"      => 239823,
  #   "filename"  => "nature.jpg",
  #   "mime_type" => "image/jpeg"
  # }

  "foo"
end

add_metadata :bar do |io, context|
  context[:metadata] #=>
  # {
  #   "size"      => 239823,
  #   "filename"  => "nature.jpg",
  #   "mime_type" => "image/jpeg",
  #   "foo"       => "foo"
  # }

  "bar"
end
```
