# File Processing

Shrine allows you to process files in two ways. One is processing [on
upload](#processing-on-upload), where the processing gets triggered when the file is
attached to a record. The other is [on-the-fly](#on-the-fly-processing)
processing, where the processing is performed lazily at the moment the file is
requested.

With both ways you need to define some kind of processing block, which accepts
a source file and is expected to return the processed result file.

```rb
some_process_block do |source_file|
 # process source file and return the result
end
```

How you're going to implement processing is entirely up to you. For images it's
recommended to use the **[ImageProcessing]** gem, which provides wrappers for
processing with [ImageMagick]/[GraphicsMagick] (using the [MiniMagick] gem) or
[libvips] (using the [ruby-vips] gem) (see the [libvips section](#libvips)).
Here is an example of generating a 600x400 thumbnail with ImageProcessing:

```sh
$ brew install imagemagick
```

```rb
# Gemfile
gem "image_processing", "~> 1.0"
```

```rb
require "image_processing/mini_magick"

thumbnail = ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit!(600, 400)

thumbnail #=> #<Tempfile:...> (a 600x400 thumbnail of the source image)
```

## Processing on upload

Shrine allows you to process files before they're uploaded to a storage. It's
generally best to process cached files when they're being promoted to permanent
storage, because (a) at that point the file has already been successfully
[validated][validation], (b) the parent record has been saved and the database
transaction has been committed, and (c) this can be delayed into a [background
job][backgrounding].

You can define processing using the `processing` plugin, which we'll use to
hook into the `:store` phase (when cached file is uploaded to permanent
storage).

```rb
class ImageUploader < Shrine
  plugin :processing

  process(:store) do |io, context|
    io      #=> #<Shrine::UploadedFile ...>
    context #=> {:record=>#<Photo...>,:name=>:image,...}

    # ...
  end
end
```

The processing block yields two arguments: a [`Shrine::UploadedFile`] object
representing the file uploaded to temporary storage, and a Hash containing
additional data such as the model instance and attachment name. The block
result should be file(s) that will be uploaded to permanent storage.

### Versions

Let's say we're handling images, and want to generate thumbnails of various
dimensions. In this case we can use the ImageProcessing gem to generate the
thumbnails, and return a hash of processed files at the end of the block. We'll
need to load the `versions` plugin which extends Shrine with the ability to
handle collections of files inside the same attachment.

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :processing # allows hooking into promoting
  plugin :versions   # enable Shrine to handle a hash of files
  plugin :delete_raw # delete processed files after uploading

  process(:store) do |io, context|
    versions = { original: io } # retain original

    # download the uploaded file from the temporary storage
    io.download do |original|
      pipeline = ImageProcessing::MiniMagick.source(original)

      versions[:large]  = pipeline.resize_to_limit!(800, 800)
      versions[:medium] = pipeline.resize_to_limit!(500, 500)
      versions[:small]  = pipeline.resize_to_limit!(300, 300)
    end

    versions # return the hash of processed files
  end
end
```

**NOTE: It's recommended to always keep the original file, just in case you'll
ever need to reprocess it.**

### Conditional processing

The process block yields the attached file uploaded to temporary storage, so we
have information like file extension and MIME type available. Together with
ImageProcessing's chainable API, it's easy to do conditional proccessing.

For example, let's say we want our thumbnails to be either JPEGs or PNGs, and
we also want to save JPEGs as progressive (interlaced). Here's how the code for
this might look like:

```rb
process(:store) do |io, context|
  versions = { original: io }

  io.download do |original|
    pipeline = ImageProcessing::Vips.source(original)

    # Shrine::UploadedFile object contains information about the MIME type
    unless io.mime_type == "image/png"
      pipeline = pipeline
        .convert("jpeg")
        .saver(interlace: true)
    end

    versions[:large]  = pipeline.resize_to_limit!(800, 800)
    versions[:medium] = pipeline.resize_to_limit!(500, 500)
    versions[:small]  = pipeline.resize_to_limit!(300, 300)
  end

  versions
end
```

### Processing other file types

So far we've only been talking about processing images. However, there is
nothing image-specific in Shrine's processing API, you can just as well process
any other types of files. The processing tool doesn't need to have any special
Shrine integration, the ImageProcessing gem that we saw earlier is a completely
generic gem.

To demonstrate, here is an example of transcoding videos using
[streamio-ffmpeg]:

```rb
require "streamio-ffmpeg"
require "tempfile"

class VideoUploader < Shrine
  plugin :processing
  plugin :versions
  plugin :delete_raw

  process(:store) do |io, context|
    versions = { original: io }

    io.download do |original|
      transcoded = Tempfile.new(["transcoded", ".mp4"], binmode: true)
      screenshot = Tempfile.new(["screenshot", ".jpg"], binmode: true)

      movie = FFMPEG::Movie.new(original.path)
      movie.transcode(transcoded.path)
      movie.screenshot(screenshot.path)

      [transcoded, screenshot].each(&:open) # refresh file descriptors

      versions.merge!(transcoded: transcoded, screenshot: screenshot)
    end

    versions
  end
end
```

## On-the-fly processing

Generating image thumbnails on upload can be a pain to maintain, because
whenever you need to add a new version or change an existing one, you need to
retroactively apply it to all existing uploads (see the [Reprocessing Versions]
guide for more details).

As an alternative, it's very common to instead generate thumbnails dynamically
as they're requested, and then cache them for future requests. This strategy is
known as "on-the-fly processing", and it's suitable for generating thumbnails
or document previews.

Shrine provides on-the-fly processing functionality via the
[`derivation_endpoint`][derivation_endpoint] plugin. The basic setup is the
following:

1. load the plugin with a secret key and a path prefix for the endpoint
2. mount the endpoint into your main app's router
3. define a processing block for the type files you want to generate

Together it might look something like this:

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :derivation_endpoint,
    secret_key: "<YOUR SECRET KEY>",
    prefix:     "derivations/image"

  derivation :thumbnail do |file, width, height|
    ImageProcessing::MiniMagick
      .source(file)
      .resize_to_limit!(width.to_i, height.to_i)
  end
end
```

```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  mount ImageUploader.derivation_endpoint => "derivations/image"
end
```

Now you can generate thumbnail URLs from attached files, and the actual
thumbnail will be generated when the URL is requested:

```rb
photo.image.derivation_url(:thumbnail, "600", "400")
#=> "/derivations/image/thumbnail/600/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
```

The plugin is highly customizable, be sure to check out the
[documnetation][derivation_endpoint], especially the [performance
section][derivation_endpoint performance].

## Extras

### libvips

As mentioned, ImageProcessing gem also has an alternative backend for
processing images with **[libvips]**. libvips is a full-featured image
processing library like ImageMagick, with impressive performance
characteristics – it's often multiple times faster than ImageMagick and has low
memory usage (see [Why is libvips quick]).

Using libvips is as easy as installing it and switching to the
`ImageProcessing::Vips` backend:

```sh
$ brew install vips
```

```rb
# Gemfile
gem "image_processing", "~> 1.0"
```

```rb
require "image_processing/vips"

# all we did was replace `ImageProcessing::MiniMagick` with `ImageProcessing::Vips`
thumbnail = ImageProcessing::Vips
  .source(image)
  .resize_to_limit!(600, 400)

thumbnail #=> #<Tempfile:...> (a 600x400 thumbnail of the source image)
```

### Optimizing thumbnails

If you're generating image thumbnails, you can additionally use the
[image_optim] gem to further reduce their filesize:

```rb
# Gemfile
gem "image_processing", "~> 1.0"
gem "image_optim"
gem "image_optim_pack" # precompiled binaries
```

```rb
require "image_processing/mini_magick"

thumbnail = ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit!(600, 400)

image_optim = ImageOptim.new
image_optim.optimize_image!(thumbnail.path)

thumbnail.open # refresh file descriptor
thumbnail
```

### External processing

Since processing is so dynamic, you're not limited to using the ImageProcessing
gem, you can also use a 3rd-party service to generate thumbnails for you. Here
is an example of generating thumbnails on-the-fly using [ImageOptim.com] (not
to be confused with the [image_optim] gem):

```rb
# Gemfile
gem "down", "~> 4.4"
gem "http", "~> 4.0"
```

```rb
require "down/http"

class ImageUploader < Shrine
  plugin :derivation_endpoint,
    secret_key: "secret",
    prefix:     "derivations/image",
    download:   false

  derivation :thumbnail do |source, width, height|
    # generate thumbnails using ImageOptim.com
    down = Down::Http.new(method: :post)
    down.download("https://im2.io/<USERNAME>/#{width}x#{height}/#{source.url}")
  end
end
```

### Cloudinary

[Cloudinary] is a popular commercial service for on-the-fly image processing,
so it's a good alternative to the `derivation_endpoint` plugin. The
[shrine-cloudinary] gem provides a Shrine storage that we can set for our
temporary and permanent storage:

```rb
# Gemfile
gem "shrine-cloudinary"
```

```rb
require "cloudinary"
require "shrine/storage/cloudinary"

Cloudinary.config(
  cloud_name: "<YOUR_CLOUD_NAME>",
  api_key:    "<YOUR_API_KEY>",
  api_secret: "<YOUR_API_SECRET>",
)

Shrine.storages = {
  cache: Shrine::Storage::Cloudinary.new(prefix: "cache"),
  store: Shrine::Storage::Cloudinary.new,
}
```

Now when we upload our images to Cloudinary, we can generate URLs with various
processing parameters:

```rb
photo.image.url(width: 100, height: 100, crop: :fit)
#=> "http://res.cloudinary.com/myapp/image/upload/w_100,h_100,c_fit/nature.jpg"
```

[`Shrine::UploadedFile`]: http://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html
[ImageProcessing]: https://github.com/janko/image_processing
[ImageMagick]: https://www.imagemagick.org
[GraphicsMagick]: http://www.graphicsmagick.org
[libvips]: http://libvips.github.io/libvips/
[Why is libvips quick]: https://github.com/libvips/libvips/wiki/Why-is-libvips-quick
[image_optim]: https://github.com/toy/image_optim
[ImageOptim.com]: https://imageoptim.com/api
[streamio-ffmpeg]: https://github.com/streamio/streamio-ffmpeg
[Reprocessing Versions]: doc/regenerating_versions.md#readme
[Cloudinary]: https://cloudinary.com
[shrine-cloudinary]: https://github.com/shrinerb/shrine-cloudinary
[backgrounding]: doc/plugins/backgrounding.md#readme
[validation]: doc/validation.md#readme
[ruby-vips]: https://github.com/libvips/ruby-vips
[MiniMagick]: https://github.com/minimagick/minimagick
[derivation_endpoint]: doc/plugins/derivation_endpoint.md#readme
[derivation_endpoint performance]: doc/plugins/derivation_endpoint.md#performance
