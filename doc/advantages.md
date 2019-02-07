# Advantages of Shrine

There are many existing file upload solutions for Ruby out there – [Paperclip],
[CarrierWave], [Dragonfly], [Refile], and [Active Storage], to name the most
popular ones. This guide will attempt to cover some of the main advantages that
Shrine offers compared to these alternatives.

## Generality

Many alternative file upload solutions are coupled to either Rails (Active
Storage) or Active Record itself (Paperclip, Dragonfly). This is not ideal, as
Rails-specific solutions fragment the Ruby community between developers that
use Rails and developers that don't. There are many great web frameworks
([Sinatra], [Roda], [Cuba], [Hanami], [Grape]) and database libraries
([Sequel], [ROM], [Hanami::Model]) out there that people use instead of
Rails and Active Record.

Shrine, on the other hand, doesn't make any assumptions about which web
framework or ORM you're using. Any web-specific functionality is implemented
on top of [Rack], the Ruby web server interface that powers all the popular
Ruby web frameworks (including Rails). The integrations for specific ORMs are
provided as plugins.

```rb
# Rack-based plugins
Shrine.plugin :upload_endpoint
Shrine.plugin :presign_endpoint
Shrine.plugin :download_endpoint
Shrine.plugin :derivation_endpoint
Shrine.plugin :rack_response
Shrine.plugin :rack_file

# ORM plugins
Shrine.plugin :activerecord
Shrine.plugin :sequel
Shrine.plugin :mongoid # https://github.com/shrinerb/shrine-mongoid
Shrine.plugin :hanami # https://github.com/katafrakt/hanami-shrine
```

## Simplicity

Shrine was designed with simplicity in mind. Where other solutions favour
complex class-level DSLs, Shrine chooses simple instance-level interfaces where
you can write regular Ruby code.

There are no `CarrierWave::Uploader::Base` and `Paperclip::Attachment` [god
objects], Shrine has several core classes each with clear responsibilities:

* Storage classes encapsulate file operations for the underlying service
* `Shrine` handles uploads and manages plugins
* `Shrine::UploadedFile` repesents a file that was uploaded to a storage
* `Shrine::Attacher` handles attaching files to records
* `Shrine::Attachment` adds convenience methods to model instances

```rb
photo.image          #=> #<Shrine::UploadedFile>
photo.image.storage  #=> #<Shrine::Storage::S3>
photo.image.uploader #=> #<Shrine>
photo.image_attacher #=> #<Shrine::Attacher>
```

Special care was taken to make integrating new storages and ORMs possible with
minimal amount of code.

## Modularity

Shrine uses a [plugin system] that allows you to pick and choose the features
that you want. Moreover, you're only loading the code for features that you
use, which means that Shrine will generally load very fast.

```rb
Shrine.plugin :logging

# translates to

require "shrine/plugins/logging"
Shrine.plugin Shrine::Plugins::Logging
```

Shrine comes with a complete attachment functionality, but it also exposes many
low level APIs that can be used for building your own customized attachment
flow. For example, if you prefer the `Attachment`/`Blob` architecture Active
Storage provides, you can ditch the Shrine's attachment implementation and use
uploaders and uploaded files that are decoupled from attachment:

```rb
uploader      = ImageUploader.new(:store)
uploaded_file = uploader.upload(image) # metadata extraction, upload location generation

uploaded_file.id       #=> "44ccafc10ce6a4ff22829e8f579ee6b9.jpg"
uplaoded_file.metadata #=> { ... extracted metadata ... }

data = uploaded_file.to_json # serialization
# ...
uploaded_file = ImageUploader.uploaded_file(data) # deserialization

uploaded_file.url #=> "https://..."
uploaded_file.download { |tempfile| ... } # streaming download
uploaded_file.delete
```

### Dependencies

Shrine is very diligent when it comes to dependencies. It has two mandatory
dependencies – [Down] and [ContentDisposition] – which are loaded only by
components that need them. Some Shrine plugins require additional dependencies,
but you only need to load them if you're using those plugins.

Moreover, Shrine often gives you the ability choose between multiple
alternative dependencies for doing the same task. For example, the
`determine_mime_type` plugin allows you to choose between the [`file`] command,
[FileMagic], [FastImage], [MimeMagic], or [Marcel] gem for determining the MIME
type, while the `store_dimensions` plugin can extract dimensions using
[FastImage], [MiniMagick], or [ruby-vips] gem.

```rb
Shrine.plugin :determine_mime_type, analyzer: :marcel
Shrine.plugin :store_dimensions,    analyzer: :mini_magick
```

This approach gives you control over your dependencies by allowing you to
choose the combination that best suit your needs.

## Inheritance

Shrine is designed to handle any types of files. If you're accepting uploads of
multiple types of files, such as videos and images, chances are that the logic
for handling them will be very different:

* small images can be processed on-the-fly, but large files should be processed in a background job
* which storage service is most suitable might depend on the filetype (images, documents, audios, videos)
* different filetypes have different metadata to extract which require different tools

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

Most file attachment libraries give you the ability to process files either "on
upload" (Paperclip, CarrierWave) or "on-the-fly" (Dragonfly, Refile, Active
Storage). Having only one option is not ideal, because some type of files
it's more suitable to process on-the-fly (image thumbnails, document previews),
while other types of files should be processed in a background job (video
transcoding, raw images)

Shrine is the first file attachment library that has support for both
processing on upload and on-the-fly. So, if you're handling image uploads, you
can choose to either generate a set of pre-defined image thumbnails in a
background job:

```rb
class ImageUploader < Shrine
  process(:store) do |io|
    versions = { original: io }

    io.download do |original|
      pipeline = ImageProcessing::MiniMagick.source(original)

      versions[:large]  = pipeline.resize_to_limit!(800, 800)
      versions[:medium] = pipeline.resize_to_limit!(500, 500)
      versions[:small]  = pipeline.resize_to_limit!(300, 300)
    end

    versions
  end
end
```

or generate thumbnails on-demand:

```rb
class ImageUploader < Shrine
  derivation :thumbnail do |file, width, height|
    ImageProcessing::MiniMagick
      .source(file)
      .resize_to_limit!(width.to_i, height.to_i)
  end
end
```
```rb
photo.image.derivation_url(:thumbnail, "600", "400")
#=> ".../thumbnail/600/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
```

### Image processing

Many file attachment libraries, such as CarrierWave, Paperclip, Dragonfly and
Refile, implement their own image processing macros. Instead of creating
yet another in-house implementation, the **[ImageProcessing]** gem was created.

Even though the ImageProcessing gem was created for Shrine, it's completely
generic and can be used standalone, or in any other file upload library (e.g.
Active Storage uses it now as well). It takes care of many details for you,
such as [auto orienting] the input image and [sharpening] the thumbnails after
they are resized.

```rb
require "image_processing"

thumbnail = ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit(400, 400)
  .call # convert input.jpg -auto-orient -resize 400x400> -sharpen 0x1 output.jpg

thumbnail #=> #<Tempfile:/var/folders/.../image_processing20180316-18446-1j247h6.png>
```

#### libvips

Probably the biggest ImageProcessing feature is the support for **[libvips]**.
libvips is a full-featured image processing library like ImageMagick, with
impressive performance characteristics – it's often multiple times faster than
ImageMagick and has low memory usage (see [Why is libvips quick]).

The `ImageProcessing::Vips` backend implements the same API as
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

Both processing "on upload" and "on-the-fly" work in a way that you define a
Ruby block, which accepts a source file and is expected to return a processed
file. How you're going to do the processing is entirely up to you.

This allows you to use any tool you want. For example, you could use the
[image_optim] gem to perform additional image optimizations:

```rb
class VideoUploader < Shrine
  derivation :thumbnail do |file, width, height|
    thumbnail = ImageProcessing::MiniMagick
      .source(file)
      .resize_to_limit!(width, height)

    image_optim = ImageOptim.new
    image_optim.optimize_image!(thumbnail.path)

    thumbnail
  end
end
```

## Metadata & Validation

Shrine automatically [extracts metadata][metadata] from each uploaded file,
including derivatives like image thumbnails, and saves them into the database
column. In addition to filename, filesize, and MIME type that are extracted by
default, you can also extract [image dimensions][store_dimensions], or your own
[custom metadata][add_metadata].

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

For common metadata there are already [validation macros][validation_helpers],
but you can also [validate any custom metadata][custom validations].

```rb
class DocumentUploader < Shrine
  Attacher.validate do
    # validation macros
    validate_max_size 10*1024*1024
    validate_mime_type_inclusion %W[application/pdf]

    # custom validations
    if get.metadata["page_count"] > 30
      errors << "has too many pages (max is 30)"
    end
  end
end
```

## Backgrounding

In most file upload solutions background processing was an afterthought, which
resulted in complex implementations. Shrine was designed with backgrounding
feature in mind from day one. It is supported via the
[`backgrounding`][backgrounding] plugin and can be used with [any backgrounding
library][backgrounding libraries].

## Direct Uploads

Shrine doesn't come with a plug-and-play JavaScript solution for client-side
uploads like Refile and Active Storage, but instead it adopts **[Uppy]**. Uppy
is a modern JavaScript file upload library, which offers support for uploading
to [AWS S3][AwsS3], to a [custom endpoint][XHRUpload], or even to a [resumable
endpoint][Tus]. It comes with a set of UI components, ranging from a simple
[status bar][StatusBar] to a full-featured [dashboard][Dashboard]. Since Uppy
is maintained by the wide JavaScript community, it's generally a better choice
than any homegrown solution.

Shrine provides Rack components for uploads that integrate nicely with Uppy.
So, whether you want Uppy to upload directly [to your app][upload_endpoint], or
you want to authorize direct uploads [to the cloud][presign_endpoint], Shrine
has it streamlined.

### Resumable uploads

If your users are uploading large files, flaky internet connections can cause
uploads to fail halfway, which can be a frustrating user experience. To fix
this problem, [Transloadit] company has created an open HTTP-based protocol for
resumable uploads – **[tus]**. There are already countless client and server
[implementations][tus implementations] of the protocol in various languages.

So, if you're expecting large file uploads, you can use Uppy as a [JavaScript
client][Tus] and have it upload to [Ruby server][tus-ruby-server], then attach
uploaded files using the handy [Shrine integration][shrine-tus]. Shrine handles
uploads and downloads in a streaming fashion, so you can expect low memory
usage.

Alternatively, you can have [resumable multipart uploads directly to
S3][uppy-s3_multipart].

## Security

It's [important][OWASP] to care about security when handling file uploads, and
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
`remote_url` plugin uses will [terminate the download early][Down max size]
when it realizes it's too large.

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
[Down]: https://github.com/janko/down
[ContentDisposition]: https://github.com/shrinerb/content_disposition
[`file`]: http://linux.die.net/man/1/file
[FileMagic]: https://github.com/blackwinter/ruby-filemagic
[FastImage]: https://github.com/sdsykes/fastimage
[MimeMagic]: https://github.com/minad/mimemagic
[Marcel]: https://github.com/basecamp/marcel
[mime-types]: https://github.com/mime-types/ruby-mime-types
[mini_mime]: https://github.com/discourse/mini_mime
[MiniMagick]: https://github.com/minimagick/minimagick
[ruby-vips]: https://github.com/libvips/ruby-vips
[god objects]: https://en.wikipedia.org/wiki/God_object
[ImageMagick]: https://www.imagemagick.org
[refile-mini_magick]: https://github.com/refile/refile-mini_magick
[ImageProcessing]: https://github.com/janko/image_processing
[auto orienting]: https://www.imagemagick.org/script/command-line-options.php#auto-orient
[sharpening]: https://photography.tutsplus.com/tutorials/what-is-image-sharpening--cms-26627
[libvips]: http://libvips.github.io/libvips/
[Why is libvips quick]: https://github.com/libvips/libvips/wiki/Why-is-libvips-quick
[metadata]: /doc/metadata.md#readme
[store_dimensions]: /doc/plugins/store_dimensions.md#readme
[add_metadata]: /doc/plugins/add_metadata.md#readme
[validation]: /doc/validation.md#readme
[upload_endpoint]: /doc/plugins/upload_endpoint.md#readme
[presign_endpoint]: /doc/plugins/presign_endpoint.md#readme
[Uppy]: https://uppy.io
[XHRUpload]: https://uppy.io/docs/xhrupload/
[AwsS3]: https://uppy.io/docs/aws-s3/
[Tus]: https://uppy.io/docs/tus/
[StatusBar]: https://uppy.io/examples/statusbar/
[Dashboard]: https://uppy.io/examples/dashboard/
[backgrounding]: /doc/plugins/backgrounding.md#readme
[backgrounding libraries]: https://github.com/shrinerb/shrine/wiki/Backgrounding-Libraries
[Down streaming]: https://github.com/janko/down#streaming
[Transloadit]: https://transloadit.com
[tus]: https://tus.io
[tus implementations]: https://tus.io/implementations.html
[tus-ruby-server]: https://github.com/janko/tus-ruby-server
[shrine-tus]: https://github.com/shrinerb/shrine-tus
[ImageTragick]: https://imagetragick.com
[uppy-s3_multipart]: https://github.com/janko/uppy-s3_multipart
[OWASP]: https://www.owasp.org/index.php/Unrestricted_File_Upload
[image_optim]: https://github.com/toy/image_optim
[validation_helpers]: /doc/plugins/validation_helpers.md#readme
[custom validations]: /doc/validation.md#custom-validations
[Down max size]: https://github.com/janko/down#maximum-size
