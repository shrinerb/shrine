---
title: Advantages of Shrine
---

There are many existing file upload solutions for Ruby out there. This guide
will attempt to cover some of the main advantages that Shrine offers compared
to these alternatives.

For a more direct comparison with specific file attachment libraries, there are
more specialized guides for [CarrierWave], [Paperclip], and [Refile] users.

## Generality

Many alternative file upload solutions are coupled to either Rails (Active
Storage) or Active Record itself (Paperclip, Dragonfly). This is not ideal, as
Rails-specific solutions fragment the Ruby community between developers that
use Rails and developers that don't. There are many great web frameworks
([Sinatra], [Roda], [Cuba], [Hanami], [Grape]) and persistence libraries
([Sequel], [ROM], [Hanami::Model]) out there that people use instead of Rails
and Active Record.

Shrine, on the other hand, doesn't make any assumptions about which web
framework or persistence library you're using. Any web-specific functionality
is implemented on top of [Rack], the Ruby web server interface that powers all
the popular Ruby web frameworks (including Rails). The integrations for
specific ORMs are provided as plugins.

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
Shrine.plugin :rom # https://github.com/shrinerb/shrine-rom
Shrine.plugin :hanami # https://github.com/katafrakt/hanami-shrine
```

## Simplicity

Where some popular file attachment libraries have [god objects]
(`CarrierWave::Uploader::Base` and `Paperclip::Attachment`), Shrine distributes
responsibilities across multiple core classes:

| Class                  | Description                                            |
| :----                  | :-----------                                           |
| `Shrine::Storage::*`   | Encapsulate file operations for the underlying service |
| `Shrine`               | Wraps uploads and handles loading plugins              |
| `Shrine::UploadedFile` | Represents a file that was uploaded to a storage       |
| `Shrine::Attacher`     | Handles attaching files to records                     |
| `Shrine::Attachment`   | Adds convenience attachment methods to model instances |

```rb
photo.image           #=> #<Shrine::UploadedFile>
photo.image.storage   #=> #<Shrine::Storage::S3>
photo.image.uploader  #=> #<Shrine>
photo.image_attacher  #=> #<Shrine::Attacher>
photo.class.ancestors #=> [..., #<Shrine::Attachment(:image)>, ...]
```

The attachment functionality is decoupled from persistence and storage, which
makes it much easier to reason about. Also, special care was taken to make
integrating new storages and persistence libraries as easy as possible.

## Modularity

Shrine uses a [plugin system] that allows you to pick and choose the features
that you want. Moreover, you'll only be loading code for the features you've
selected, which means that Shrine will generally load much faster than the
alternatives.

```rb
Shrine.plugin :instrumentation

# which translates to

require "shrine/plugins/instrumentation"
Shrine.plugin Shrine::Plugins::Instrumentation
```
```rb
Shrine.method(:instrument).owner #=> Shrine::Plugins::Instrumentation::ClassMethods
```

Shrine recommends a certain type of attachment flow, but it still offers good
low-level abstractions that give you the flexibility to build your own flow.

```rb
uploaded_file = ImageUploader.upload(image, :store) # metadata extraction, upload location generation
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
components that need them. Some Shrine plugins also require additional
dependencies, but you only need to load them if you're using those plugins.

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

## Inheritance

Shrine is designed to handle any types of files. If you're accepting uploads of
multiple types of files, such as videos and images, chances are that the logic
for handling them will differ:

* small images can be processed on-the-fly, but large files should be processed in a background job
* you might want to store different files to different storage services (images, documents, audios, videos)
* extracting metadata might require different tools depending on the filetype

With Shrine you can create isolated uploaders for each type of file. For
features you want all uploaders to share, their plugins can be loaded globally,
while other plugins you can load only for selected uploaders.

```rb
# loaded for all plugins
Shrine.plugin :activerecord
Shrine.plugin :instrumentation
```
```rb
class ImageUploader < Shrine
  # loaded only for ImageUploader
  plugin :store_dimensions
end
```
```rb
class VideoUploader < Shrine
  # loaded only for VideoUploader
  plugin :default_storage, store: :vimeo
end
```

## Processing

Most file attachment libraries provide either processing files up front
(Paperclip, CarrierWave) or on-the-fly (Dragonfly, Refile, Active Storage).
However, each approach is suitable for different requirements. For instance,
while on-the-fly processing is suitable for fast processing (image thumbnails,
document previews), longer running processing (video transcoding, raw images)
should be moved into a background job.

That's why Shrine supports both [up front][derivatives] and
[on-the-fly][derivation_endpoint] processing. For example, if you're handling
image uploads, you can choose to either generate a set of pre-defined
thumbnails during attachment:

```rb
class ImageUploader < Shrine
  Attacher.derivatives_processor do |original|
    magick = ImageProcessing::MiniMagick.source(original)

    {
      large:  magick.resize_to_limit!(800, 800),
      medium: magick.resize_to_limit!(500, 500),
      small:  magick.resize_to_limit!(300, 300),
    }
  end
end
```
```rb
photo.image_derivatives! # creates thumbnails
photo.image_url(:large)  #=> "https://s3.amazonaws.com/path/to/large.jpg"
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
photo.image.derivation_url(:thumbnail, 600, 400)
#=> ".../thumbnail/600/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
```

### ImageMagick

Many file attachment libraries, such as CarrierWave, Paperclip, Dragonfly and
Refile, implement their own image processing macros. Rather than building yet
another in-house implementation, a general purpose **[ImageProcessing]** gem
was created instead, which works great with Shrine.

```rb
require "image_processing/mini_magick"

thumbnail = ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit(400, 400)
  .call # convert input.jpg -auto-orient -resize 400x400> -sharpen 0x1 output.jpg

thumbnail #=> #<Tempfile:/var/folders/.../image_processing20180316-18446-1j247h6.jpg>
```

It takes care of many details for you, such as [auto orienting] the input image
and applying [sharpening] to resized images. It also has support for
[libvips](#libvips).

### libvips

**[libvips]** is a full-featured image processing library like ImageMagick,
with [great performance characteristics][libvips performance]. It's often
**multiple times faster** than ImageMagick, and also has lower memory usage.
For more details, see [Why is libvips quick].

The ImageProcessing gem provides libvips support as an alternative
`ImageProcessing::Vips` backend, sharing the same API as the
`ImageProcessing::MiniMagick` backend.

```rb
require "image_processing/vips"

# this now generates the thumbnail using libvips
ImageProcessing::Vips
  .source(image)
  .resize_to_limit!(400, 400)
```

### Other processors

In contrast to most file attachment libraries, file processing in Shrine is
just a functional transformation, where you receive the source file on the
input and return processed files on the output. This makes it easier to use
custom processing tools and encourages building generic processors that can be
reused outside of Shrine.

Here is an example of transcoding videos using the [streamio-ffmpeg] gem:

```rb
# Gemfile
gem "streamio-ffmpeg"
```
```rb
class VideoUploader < Shrine
  Attacher.derivatives_processor do |original|
    transcoded = Tempfile.new ["transcoded", ".mp4"]
    screenshot = Tempfile.new ["screenshot", ".jpg"]

    movie = FFMPEG::Movie.new(original.path)
    movie.transcode(transcoded.path)
    movie.screenshot(screenshot.path)

    { transcoded: transcoded, screenshot: screenshot }
  end
end
```
```rb
movie.video_derivatives! # create derivatives

movie.video              #=> #<Shrine::UploadedFile id="5a5cd0.mov" ...>
movie.video(:transcoded) #=> #<Shrine::UploadedFile id="7481d6.mp4" ...>
movie.video(:screenshot) #=> #<Shrine::UploadedFile id="8f3136.jpg" ...>
```

## Metadata

Shrine automatically [extracts metadata][metadata] from each uploaded file,
including derivatives like image thumbnails, and saves them into the database
column. In addition to filename, filesize, and MIME type that are extracted by
default, you can also extract [image dimensions][store_dimensions], or your own
[custom metadata][add_metadata].

```rb
class ImageUploader < Shrine
  plugin :determine_mime_type # mime_type
  plugin :store_dimensions    # width & height

  add_metadata :resolution do |io|
    image = MiniMagick::Image.new(io.path)
    image.resolution
  end
end
```
```rb
photo.image.metadata #=>
# {
#   "size" => 42487494,
#   "filename" => "nature.jpg",
#   "mime_type" => "image/jpeg",
#   "width" => 600,
#   "height" => 400,
#   "resolution" => [72, 72],
#   ...
# }
```

## Validation

For file validations there are [built-in validators][validation_helpers], but
you can also just use plain Ruby code:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 10*1024*1024
    validate_extension %w[jpg jpeg png webp]

    if validate_mime_type %W[image/jpeg image/png image/webp]
      validate_max_dimensions [5000, 5000]

      unless ImageProcessing::MiniMagick.valid_image?(file.download.path)
        error << "seems to be corrupted"
      end
    end
  end
end
```

## Backgrounding

In most file upload solutions, support for background processing was an
afterthought, which resulted in complex and unreliable implementations. Shrine
was designed with backgrounding feature in mind from day one. It is supported
via the [`backgrounding`][backgrounding] plugin and can be used with [any
backgrounding library][backgrounding libraries].

```rb
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
    attacher.create_derivatives # perform processing
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    # attachment changes are detected for concurrency safety
  end
end
```

With Shrine, there is no need for a separate boolean column that indicates the
processing status. Processed file data is stored into the attachment database
column, which allows you to easily check whether a file has been processed.

```rb
photo = Photo.create(image: file) # background job is kicked off

photo.image(:large) #=> nil (thumbnails are still being processed)
# ... sometime later ...
photo.image(:large) #=> #<Shrine::UploadedFile> (processing has finished)
```

## Direct Uploads

For client side uploads, Shrine adopts **[Uppy]**, a modern JavaScript file
upload library. This gives the developer a lot more power in customizing the
user experience compared to a custom JavaScript solution implemented by Refile
and Active Storage.

Uppy supports direct uploads to [AWS S3][Uppy AwsS3] or to a [custom
endpoint][Uppy XHRUpload]. It also supports **resumable** uploads, either
[directly to S3][Uppy AwsS3Multipart] or via the [tus protocol][tus]. For the
UI you can choose from various components, ranging from a simple [status
bar][Uppy StatusBar] to a full-featured [dashboard][Uppy Dashboard].

Shrine provides server side components for each type of upload. They are built
on top of Rack, so that they can be used with any Ruby web framework.

| Uppy                                  | Shrine                                   |
| :---                                  | :-----                                   |
| [XHRUpload][Uppy XHRUpload]           | [`upload_endpoint`][upload_endpoint]     |
| [AwsS3][Uppy AwsS3]                   | [`presign_endpoint`][presign_endpoint]   |
| [AwsS3Multipart][Uppy AwsS3Multipart] | [`uppy-s3_multipart`][uppy-s3_multipart] |
| [Tus][Uppy Tus]                       | [`tus-ruby-server`][tus-ruby-server]     |

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
[ImageProcessing]: https://github.com/janko/image_processing
[auto orienting]: https://www.imagemagick.org/script/command-line-options.php#auto-orient
[sharpening]: https://photography.tutsplus.com/tutorials/what-is-image-sharpening--cms-26627
[libvips]: http://libvips.github.io/libvips/
[Why is libvips quick]: https://github.com/libvips/libvips/wiki/Why-is-libvips-quick
[metadata]: https://shrinerb.com/docs/metadata
[store_dimensions]: https://shrinerb.com/docs/plugins/store_dimensions
[add_metadata]: https://shrinerb.com/docs/plugins/add_metadata
[validation]: https://shrinerb.com/docs/validation
[upload_endpoint]: https://shrinerb.com/docs/plugins/upload_endpoint
[presign_endpoint]: https://shrinerb.com/docs/plugins/presign_endpoint
[Uppy]: https://uppy.io
[Uppy XHRUpload]: https://uppy.io/docs/xhr-upload/
[Uppy AwsS3]: https://uppy.io/docs/aws-s3/
[Uppy Tus]: https://uppy.io/docs/tus/
[Uppy AwsS3Multipart]: https://uppy.io/docs/aws-s3-multipart/
[tus]: https://tus.io
[Uppy StatusBar]: https://uppy.io/examples/statusbar/
[Uppy Dashboard]: https://uppy.io/examples/dashboard/
[tus-ruby-server]: https://github.com/janko/tus-ruby-server
[uppy-s3_multipart]: https://github.com/janko/uppy-s3_multipart
[backgrounding]: https://shrinerb.com/docs/plugins/backgrounding
[backgrounding libraries]: https://github.com/shrinerb/shrine/wiki/Backgrounding-Libraries
[Down streaming]: https://github.com/janko/down#streaming
[validation_helpers]: https://shrinerb.com/docs/plugins/validation_helpers
[derivatives]: https://shrinerb.com/docs/plugins/derivatives
[derivation_endpoint]: https://shrinerb.com/docs/plugins/derivation_endpoint
[libvips performance]: https://github.com/libvips/libvips/wiki/Speed-and-memory-use#results
[streamio-ffmpeg]: https://github.com/streamio/streamio-ffmpeg
[CarrierWave]: https://shrinerb.com/docs/carrierwave
[Paperclip]: https://shrinerb.com/docs/paperclip
[Refile]: https://shrinerb.com/docs/refile
