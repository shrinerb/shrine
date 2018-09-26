# Extracting Metadata

Before a file is uploaded, Shrine automatically extracts metadata from it, and
stores them in the `Shrine::UploadedFile` object. By default it extracts
`size`, `filename` and `mime_type`.

```rb
uploaded_file = uploader.upload(file)
uploaded_file.metadata #=>
# {
#   "size" => 345993,
#   "filename" => "matrix.mp4",
#   "mime_type" => "video/mp4",
# }
```

You can also use `Shrine#extract_metadata` directly to extract metadata from
any IO object.

```rb
uploader.extract_metadata(io) #=>
# {
#   "size" => 345993,
#   "filename" => "matrix.mp4",
#   "mime_type" => "video/mp4",
# }
```

## MIME type

By default, the `mime_type` metadata will be copied over from the
`#content_type` attribute of the input file, if present. However, since
`#content_type` value comes from the `Content-Type` header of the upload
request, it's *not guaranteed* to hold the actual MIME type of the file (browser
determines this header based on file extension). Moreover, only
`ActionDispatch::Http::UploadedFile` and `Shrine::Plugins::RackFile::UploadedFile`
objects have `#content_type` defined, so when uploading simple file objects
`mime_type` will be nil. That makes relying on `#content_type` both a security
risk and limiting.

To remedy that, Shrine comes with a `determine_mime_type` plugin which is able
to extract the MIME type from IO *content*. When you load it, the `mime_type`
plugin will now be determined using the UNIX [`file`] command.

```rb
Shrine.plugin :determine_mime_type
```
```rb
uploaded_file = uploader.upload StringIO.new("<?php ... ?>")
uploaded_file.mime_type #=> "text/x-php"
```

The `file` command won't correctly determine the MIME type in all cases, that's
why the `determine_mime_type` plugin comes with different MIME type analyzers.
So, instead of the `file` command you can use gems like [MimeMagic] or
[Marcel], as well as mix-and-match the analyzers to suit your needs. See the
plugin documentation for more details.

## Image Dimensions

Shrine comes with a `store_dimensions` plugin for extracting image dimensions.
It adds `width` and `height` metadata values, and also adds `#width`,
`#height`, and `#dimensions` methods to the `Shrine::UploadedFile` object. By
default, the plugin uses [FastImage] to analyze dimensions, but you can also
have it use [MiniMagick] or [ruby-vips]:

```rb
Shrine.plugin :store_dimensions, analyzer: :mini_magick
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

## Custom metadata

In addition to the built-in metadata, Shrine allows you to extract and store
any custom metadata, using the `add_metadata` plugin (which extends
`Shrine#extract_metadata`). For example, you might want to extract EXIF data
from images:

```rb
require "mini_magick"

class ImageUploader < Shrine
  plugin :add_metadata

  add_metadata :exif do |io|
    Shrine.with_file(io) do |file|
      begin
        MiniMagick::Image.new(file.path).exif
      rescue MiniMagick::Error
        # not a valid image
      end
    end
  end
end
```
```rb
uploaded_file = uploader.upload(image)
uploaded_file.metadata["exif"] #=> {...}
uploaded_file.exif             #=> {...}
```

Of, if you're uploading videos, you might want to extract some video-specific
meatadata:

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
If you're using the `data_uri` plugin, the `io` will be a `StringIO` wrapper.
When the `restore_cached_data` plugin is loaded, any assigned cached file will
get their metadata extracted, and `io` will be a `Shrine::UploadedFile` object.
If you're using a metadata analyzer that requires the source file to be on
disk, you can use `Shrine.with_file` to ensure you have a file object.

Also, be aware that metadata is extracted before file validation, so you'll
need to handle the cases where the file is not of expected type.

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

## Refreshing metadata

When uploading directly to the cloud, the metadata of the original file by
default won't get extracted on the server side, because your application never
received the file content.

To have Shrine extra metadata when a cached file is assigned to the attachment
attribute, it's recommended to load the `restore_cached_data` plugin.

```rb
Shrine.plugin :restore_cached_data # extract metadata from cached files on assingment
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

Extracting metadata from a cached file requires retrieving file content from
the storage, which might not be desirable depending on your case, that's why
`restore_cached_data` plugin is not loaded by default. However, Shrine will not
download the whole file from the storage, instead, it will open a connection to
the storage, and the metadata analyzers will download how much of the file they
need. Most MIME type analyzers and the FastImage dimensions analyzer need only
the first few kilobytes.

You can also extract metadata from an uploaded file explicitly using the
`refresh_metadata` plugin (which the `restore_cached_data` plugin uses
internally).

```rb
Shrine.plugin :refresh_metadata
```
```rb
uploaded_file.metadata #=> {}
uploaded_file.refresh_metadata!
uploaded_file.metadata #=> {"filename"=>"nature.jpg","size"=>532894,"mime_type"=>"image/jpeg"}
```

[`file`]: http://linux.die.net/man/1/file
[MimeMagic]: https://github.com/minad/mimemagic
[Marcel]: https://github.com/basecamp/marcel
[FastImage]: https://github.com/sdsykes/fastimage
[MiniMagick]: https://github.com/minimagick/minimagick
[ruby-vips]: https://github.com/libvips/ruby-vips
