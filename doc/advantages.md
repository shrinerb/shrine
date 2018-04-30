# Advantages of Shrine

There are many popular file upload solutions for Ruby out there – [Paperclip],
[CarrierWave], [Dragonfly], [Refile], and [Active Storage], to name the most
popular ones. This guide will attempt to cover some of the main advantages that
Shrine offers compared to these alternatives.

## Generality

Many alternative file upload solutions are coupled to either Rails (Active
Storage) or Active Record itself (Paperclip, CarrierWave, Dragonfly). This is
not ideal, as Rails-specific solutions fragment the Ruby community between
developers that use Rails and developers that don't. There are many great web
frameworks ([Sinatra], [Roda], [Cuba], [Hanami], [Grape] etc.) and database
libraries ([Sequel], [ROM], [Hanami::Model] etc.) out there that people use
instead of Rails and Active Record.

Shrine, on the other hand, doesn't make any assumptions about which web
framework or ORM you're using. Any HTTP-specific functionality is implemented
on top of [Rack], the Ruby web server interface that powers all the popular
Ruby web frameworks (including Rails). The integrations for specific ORMs are
provided as plugins.

```rb
# Rack-based plugins
Shrine.plugin :upload_endpoint
Shrine.plugin :presign_endpoint
Shrine.plugin :download_endpoint
Shrine.plugin :rack_response
Shrine.plugin :rack_file

# ORM plugins
Shrine.plugin :activerecord
Shrine.plugin :sequel
Shrine.plugin :mongoid # https://github.com/shrinerb/shrine-mongoid
Shrine.plugin :hanami # https://github.com/katafrakt/hanami-shrine
```

## Modularity

Shrine uses a [plugin system] that allows you to pick and choose the features
that you want, which makes it very flexible. Moreover, you're only loading the
code for features that you use, which means that Shrine will generally load
very fast.

```rb
Shrine.plugin :logging # loads the logging feature
```

### Dependencies

Shrine is very diligent when it comes to dependencies. It has only one
mandatory dependency - [Down], a gem for streaming downloads from a URL. Some
Shrine plugins require more dependencies, but you only need to load them if
you're using those plugins. Moreover, for the same task you can often choose
between different dependencies.

For example, if you want to determine MIME type from file content, upon loading
the `determine_mime_type` plugin you can choose whether you want to use the
[`file`] command, [FileMagic], [FastImage], [MimeMagic] or [Marcel] gem to do
that. For determining MIME type from file extension you can choose between
[mime-types] or [mini_mime] gems. Likewise, for `store_dimensions` plugin you
can choose between [FastImage], [MiniMagick] or [ruby-vips] gems for extracting
image dimensions.

```rb
Shrine.plugin :determine_mime_type, analyzer: :marcel
Shrine.plugin :store_dimensions,    analyzer: :mini_magick
```

With this approach you have control over your dependencies and are free to
choose the combination that best suit your needs.

## Simplicity

Shrine was designed with simplicity in mind. Where other solutions favour
complex class-level DSLs, Shrine chooses simple instance-level interfaces where
you can write regular Ruby code.

There are also no `CarrierWave::Uploader::Base` and `Paperclip::Attachment` [God
objects]. The `Shrine` class is responsible for uploading files to the storage
(which are simple Ruby classes), `Shrine::UploadedFile` exposes extracted
metadata and can retrieve the file from the storage, and `Shrine::Attacher`
wraps those two classes to provide an interface for attaching files to database
records.

```rb
photo.image          #=> #<Shrine::UploadedFile>
photo.image.storage  #=> #<Shrine::Storage::S3>
photo.image.uploader #=> #<Shrine>
photo.image_attacher #=> #<Shrine::Attacher>
```

Special care was taken to make integrating new ORMs and storages possible with
minimal amount of code.

## Inheritance

Shrine is designed to handle any types of files. If you're accepting uploads of
multiple types of files, such as videos and images, chances are that the logic
for handling them will be very different:

* images can be processed on-the-fly, while videos should be transcoded on upload
* you might want to store images on one service and videos on another
* tools for extracting image metadata are different than ones for video metadata

With Shrine you can create isolated uploaders for each type of file. Plugins
that you want to be applied to both uploaders can be applied globally, while
other plugins would be loaded only for a specific uploader.

```rb
Shrine.plugin :activerecord
Shrine.plugin :logging
```
```rb
class ImageUploader < Shrine
  plugin :store_dimensions
end
```
```rb
class VideoUploader < Shrine
  plugin :default_storage, store: :vimeo
end
```

## Processing

Instead of writing yet another vendored solution for generating image
thumbnails, the **[ImageProcessing]** gem was created to be used with Shrine,
but it can also be used with any other file upload library. It's very flexible
and takes care of many details for you, such as [auto orienting] the input
image and [sharpening] the thumbnails after they are resized.

```rb
require "image_processing"

thumbnail = ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit(400, 400)
  .call # convert input.jpg -auto-orient -resize 400x400> -sharpen 0x1 output.jpg

thumbnail #=> #<Tempfile:/var/folders/.../image_processing20180316-18446-1j247h6.png>
```

### libvips

Probably the biggest ImageProcessing feature is the support for **[libvips]**.
Libvips is an image processing library which can process images multiple times
faster than ImageMagick and has significantly lower memory usage (see [Why is
libvips quick]). The `ImageProcessing::Vips` backend implements the same API as
`ImageProcessing::MiniMagick`, so you can easily swap one for the other.

```rb
require "image_processing/mini_magick"
require "image_processing/vips"
require "open-uri"

original = open("https://upload.wikimedia.org/wikipedia/commons/3/36/Hopetoun_falls.jpg")

ImageProcessing::MiniMagick.resize_to_fit(800, 800).call(original)
#=> 1.0s

ImageProcessing::Vips.resize_to_fit(800, 800).call(original)
#=> 0.2s (5x faster)
```

### Other processors

Using other processors for other types of files doesn't require remembering any
specific API, you just call them in the same processing block where you're
calling ImageProcessing. Shrine's processing block acts as a functional
transformation: you get the original file on the input, and you're expected to
return processed file(s) on the output.

```rb
class VideoUploader < Shrine
  plugin :processing

  process(:store) do |io, context|
    # define your processing
  end
end
```

### On-the-fly processing

Shrine is primarily designed for processing files on upload, since that's
applicable to all types of files, while on-the-fly processing that [Dragonfly],
[Refile], and [Active Storage] offer makes sense only for images.

However, there are many specialized solutions that provide on-the-fly
processing functionality, both open source and commercial, and it's fairly easy
to apply them to files uploaded by Shrine.

```rb
Dragonfly.app
  .fetch_url(photo.image_url) # image uploaded by Shrine
  .thumb("800x800")
  .url #=> "/attachments/W1siZnUiLCJodHRwOi8vd3d3LnB1YmxpY2RvbWFpbn..."
```

## Metadata

Shrine automatically [extracts metadata][metadata] from each uploaded file,
including derivates like image thumbnails, and saves them into the database
column. In addition to filename, filesize, and MIME type that are extracted by
default, you can also extract [image dimensions][store_dimensions], or your own
[custom metadata][add_metadata]. This metadata can additionally be
[validated][validation].

```rb
photo.image.metadata #=>
# {
#   "size" => 42487494,
#   "filename" => "nature.jpg",
#   "mime_type" => "image/jpeg",
#   "width" => 600,
#   "height" => 400,
#   ...
# }
```

## Direct Uploads

Instead of submitting selected files synchronously via the form, it's better to
start uploading files asynchronously as soon as they're selected. Shrine
streamlines this workflow, allowing you to upload directly [to your
app][upload_endpoint] or [to the cloud][presign_endpoint].

[Refile] and [Active Storage] provide this functionality as well, and they also
ship with a custom plug-and-play JavaScript solution for integrating these
endpoints. In contrast, Shrine doesn't ship with any custom JavaScript but
instead recommends using **[Uppy]**. Uppy is a flexible JavaScript file upload
library that allows uploading to a [custom endpoint][XHRUpload], to [AWS
S3][AwsS3], or even to a [resumable endpoint][Tus], with the possibility to use
UI components such as a simple [status bar][StatusBar] or a complete
[dashboard][Dashboard]. Since Uppy is maintained by the whole JavaScript
community, it will generally be better than any homegrown solution.

## Backgrounding

Unlike most other file upload solutions, where background processing is an
afterthought, Shrine was designed with this feature in mind from day one. It
is supported via the `backgrounding` plugin, which provides a flexible API
that allows using [any backgrounding library][backgrounding libraries].

## Large Files

Some applications need to handle large files such as videos, and Shrine doesn't
fall short in this department. It uses and encourages streaming uploads and
downloads, where only a small part of the file is loaded into memory at any
given time. This keeps memory usage very low regardless of the size of the
files.

Shrine storages also automatically support [partial downloads][Down streaming]
(provided by the [Down] gem), which allows you to read only a portion of the
file. This can be useful for extracting metadata, because common information such
as MIME type or image dimensions are typically written in the beginning of the
file, so it's enough to download just the first few kilobytes of the file.

### Resumable uploads

Another challenge with large files is that it can be difficult for users
to upload them to your app, especially on flaky internet connections. With
a simple HTTP request, should there be any interruption during the execution,
the whole upload needs to be retried from the beginning.

To fix this problem, [Transloadit] company has created an open HTTP-based
protocol for resumable uploads – **[tus]**. To use it, you can choose from
numerous client and server [implementations][tus implementations] of the
protocol. In this case you would typically have a [JavaScript
client][tus-js-client] (via [Uppy][uppy tus]) upload to a [Ruby
server][tus-ruby-server], and then attach uploaded files using the handy
[Shrine integration][shrine-tus].

## Security

It's important to care about security when handling file uploads, and
Shrine bakes in many good practices. For starters, it uses a separate
"temporary" storage for direct uploads, making it easy to periodically clear
uploads that didn't end up being attached and difficult for the attacker to
flood the main storage.

File processing and upload to permanent storage is done outside of a database
transaction, and only after the file has been successfully validated. The
`determine_mime_type` plugin determines MIME type from the file content (rather
than relying on the `Content-Type` request header), preventing exploits like
[ImageTragick].

The `remote_url` plugin requires specifying a `:max_size` option, which limits
the maximum allowed size of the remote file. The [Down] gem which the
`remote_url` plugin uses will immediately terminate the download if it reads
from the `Content-Length` response header that the file will be too large. For
chunked responses (where `Content-Length` header is absent) the download will
will be terminated as soon as the received content surpasses the specified
limit.

[Paperclip]: https://github.com/thoughtbot/paperclip
[CarrierWave]: https://github.com/carrierwaveuploader/carrierwave
[Dragonfly]: http://markevans.github.io/dragonfly/
[Refile]: https://github.com/refile/refile
[Active Storage]: https://github.com/rails/rails/tree/master/activestorage#active-storage
[Rack]: https://rack.github.io
[Sinatra]: http://sinatrarb.com
[Roda]: http://roda.jeremyevans.net
[Cuba]: http://cuba.is
[Hanami]: http://hanamirb.org
[Grape]: https://github.com/ruby-grape/grape
[Sequel]: http://sequel.jeremyevans.net
[ROM]: http://rom-rb.org
[Hanami::Model]: https://github.com/hanami/model
[plugin system]: https://twin.github.io/the-plugin-system-of-sequel-and-roda/
[Down]: https://github.com/janko-m/down
[`file`]: http://linux.die.net/man/1/file
[FileMagic]: https://github.com/blackwinter/ruby-filemagic
[FastImage]: https://github.com/sdsykes/fastimage
[MimeMagic]: https://github.com/minad/mimemagic
[Marcel]: https://github.com/basecamp/marcel
[mime-types]: https://github.com/mime-types/ruby-mime-types
[mini_mime]: https://github.com/discourse/mini_mime
[MiniMagick]: https://github.com/minimagick/minimagick
[ruby-vips]: https://github.com/jcupitt/ruby-vips
[God objects]: https://en.wikipedia.org/wiki/God_object
[ImageMagick]: https://www.imagemagick.org
[refile-mini_magick]: https://github.com/refile/refile-mini_magick
[ImageProcessing]: https://github.com/janko-m/image_processing
[auto orienting]: https://www.imagemagick.org/script/command-line-options.php#auto-orient
[sharpening]: https://photography.tutsplus.com/tutorials/what-is-image-sharpening--cms-26627
[libvips]: http://jcupitt.github.io/libvips/
[Why is libvips quick]: https://github.com/jcupitt/libvips/wiki/Why-is-libvips-quick
[metadata]: https://shrinerb.com/rdoc/files/doc/metadata_md.html
[store_dimensions]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/StoreDimensions.html
[add_metadata]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/AddMetadata.html
[validation]: https://shrinerb.com/rdoc/files/doc/validation_md.html
[upload_endpoint]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/UploadEndpoint.html
[presign_endpoint]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/PresignEndpoint.html
[Uppy]: https://uppy.io
[XHRUpload]: https://uppy.io/docs/xhrupload/
[AwsS3]: https://uppy.io/docs/aws-s3/
[Tus]: https://uppy.io/docs/tus/
[StatusBar]: https://uppy.io/examples/statusbar/
[Dashboard]: https://uppy.io/examples/dashboard/
[background job]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/Backgrounding.html
[backgrounding libraries]: https://github.com/shrinerb/shrine/wiki/Backgrounding-libraries
[Down streaming]: https://github.com/janko-m/down#streaming
[Transloadit]: https://transloadit.com
[tus]: https://tus.io
[tus implementations]: https://tus.io/implementations.html
[tus-js-client]: https://github.com/tus/tus-js-client
[uppy tus]: https://uppy.io/docs/tus/
[tus-ruby-server]: https://github.com/janko-m/tus-ruby-server
[shrine-tus]: https://github.com/shrinerb/shrine-tus
[ImageTragick]: https://imagetragick.com
