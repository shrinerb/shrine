# File Processing

Shrine allows you to process files before they're uploaded to a storage. It's
generally best to process cached files when they're being promoted to permanent
storage, because (a) at that point the file has already been successfully
validated, (b) the parent record has been saved and the database transaction
has been committed, and (c) this can be delayed into a background job.

You can define processing using the `processing` plugin, which we'll use to
hook into the `:store` phase (when cached file is uploaded to permanent
storage).

```rb
class ImageUploader < Shrine
  plugin :processing

  process(:store) do |io, context|
    io      #=> #<Shrine::UploadedFile ...>
    context #=> {:record=>#<Photo...>,:name=>:image,...}
  end
end
```

The processing block yields two arguments: `io`, a [`Shrine::UploadedFile`]
object that's uploaded to temporary storage, and `context`, a Hash that
contains additional data such as the model instance and attachment name. The
block result should be file(s) that will be uploaded to permanent storage.

Shrine treats processing as a functional transformation; you are given the
original file, and how you're going to perform processing is entirely up to
you, you only need to return the processed files at the end of the block that
you want to save. Then Shrine will continue to upload those files to the
storage. Note that **it's recommended to always keep the original file**, just
in case you'll ever need to reprocess it.

It's a good idea to also load the `delete_raw` plugin to automatically delete
processed files after they're uploaded.

```rb
class ImageUploader < Shrine
  plugin :processing
  plugin :delete_raw # automatically delete processed files after uploading

  # ...
end
```

## Single file

Let's say that you have an image that you want to optimize before it's saved
to permanent storage. This is how you might do it with the [image_optim] gem:

```rb
# Gemfile
gem "image_optim"
gem "image_optim_pack" # precompiled binaries
```

```rb
require "image_optim"

class ImageUploader < Shrine
  plugin :processing
  plugin :delete_raw

  process(:store) do |io, context|
    original = io.download

    image_optim    = ImageOptim.new
    optimized_path = image_optim.optimize_image(original.path)

    original.close!

    File.open(optimized_path, "rb")
  end
end
```

Notice that, because the image_optim gem works with files on disk, we had to
download the cached file from temporary storage before optimizing it.
Afterwards we also close and delete it using `Tempfile#close!`.

## Versions

When you're handling images, it's very common to want to generate various
thumbnails from the original image, and display them on your site. It's
recommended to use the **[ImageProcessing]** gem for generating image
thumbnails, as it has a convenient and flexible API, and comes with good
defaults for the web.

Since we'll be storing multiple derivates of the original file, we'll need to
also load the `versions` plugin, which allows us to return a Hash of processed
files. For processing we'll be using the `ImageProcessing::MiniMagick` backend,
which performs processing with [ImageMagick]/[GraphicsMagick].

```sh
$ brew install imagemagick
```
```rb
# Gemfile
gem "image_processing", "~> 1.0"
```

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :processing
  plugin :versions
  plugin :delete_raw

  process(:store) do |io, context|
    original = io.download
    pipeline = ImageProcessing::MiniMagick.source(original)

    size_800 = pipeline.resize_to_limit!(800, 800)
    size_500 = pipeline.resize_to_limit!(500, 500)
    size_300 = pipeline.resize_to_limit!(300, 300)

    original.close!

    { original: io, large: size_800, medium: size_500, small: size_300 }
  end
end
```

### libvips

Alternatively, you can also process files with **[libvips]**, which has shown
to be multiple times faster than ImageMagick, with lower memory usage on top of
that (see [Why is libvips quick]). Using libvips is as easy as installing libvips
and switching to the `ImageProcessing::Vips` backend.

```sh
$ brew install vips
```

```rb
require "image_processing/vips"

class ImageUploader < Shrine
  plugin :processing
  plugin :versions
  plugin :delete_raw

  process(:store) do |io, context|
    original = io.download
    pipeline = ImageProcessing::Vips.source(original)

    size_800 = pipeline.resize_to_limit!(800, 800)
    size_500 = pipeline.resize_to_limit!(500, 500)
    size_300 = pipeline.resize_to_limit!(300, 300)

    original.close!

    { original: io, large: size_800, medium: size_500, small: size_300 }
  end
end
```

### External

Since processing is so dynamic, you're not limited to using the ImageProcessing
gem, you can also use a 3rd-party service to generate thumbnails for you. Here
is the same example as above, but this time using [ImageOptim.com] to do the
processing (not to be confused with the [image_optim] gem):

```rb
# Gemfile
gem "down", "~> 4.4"
gem "http", "~> 3.2"
```

```rb
require "down/http"

class ImageUploader < Shrine
  plugin :processing
  plugin :versions
  plugin :delete_raw

  IMAGE_OPTIM_URL = "https://im2.io/<USERNAME>"

  process(:store) do |io, context|
    down = Down::Http.new(method: :post)

    size_800 = down.download("#{IMAGE_OPTIM_URL}/800x800/#{io.url}")
    size_500 = down.download("#{IMAGE_OPTIM_URL}/500x500/#{io.url}")
    size_300 = down.download("#{IMAGE_OPTIM_URL}/300x300/#{io.url}")

    { original: io, large: size_800, medium: size_500, small: size_300 }
  end
end
```

We used the [Down] gem to download response bodies into tempfiles, specifically
its [HTTP.rb] backend, as it supports changing the request method and uses an
order of magnitude less memory than the default backend. Notice that we didn't
have to download the original file from temporary storage as ImageOptim.com
allows us to provide a URL.

## Conditional processing

As we've seen, Shrine's processing API allows us to process files with regular
Ruby code. This means that we can make processing dynamic by using regular Ruby
conditionals.

For example, let's say we want our thumbnails to be either JPEGs or PNGs, and
we also want to save JPEGs as progressive (interlaced). Here's how the code for
this might look like:

```rb
require "image_processing/vips"

class ImageUploader < Shrine
  plugin :processing
  plugin :versions
  plugin :delete_raw

  process(:store) do |io, context|
    original = io.download
    pipeline = ImageProcessing::Vips.source(original)

    # the `io` object contains the MIME type of the original file
    if io.mime_type != "image/png"
      pipeline = pipeline
        .convert("jpeg")
        .saver(interlace: true)
    end

    size_800 = pipeline.resize_to_limit!(800, 800)
    size_500 = pipeline.resize_to_limit!(500, 500)
    size_300 = pipeline.resize_to_limit!(300, 300)

    original.close!

    { original: io, large: size_800, medium: size_500, small: size_300 }
  end
end
```

## Processing other file types

So far we've only been talking about processing images. However, there is
nothing image-specific in Shrine's processing API, you can just as well process
any other types of files. The processing tool doesn't need to have any special
Shrine integration, the ImageProcessing gem that we saw earlier is a completely
generic gem.

To demonstrate, here is an example of transcoding videos using
[streamio-ffmpeg]:

```sh
$ brew install ffmpeg
```

```rb
# Gemfile
gem "streamio-ffmpeg"
```

```rb
require "streamio-ffmpeg"

class VideoUploader < Shrine
  plugin :processing
  plugin :versions
  plugin :delete_raw

  process(:store) do |io, context|
    original   = io.download
    transcoded = Tempfile.new(["transcoded", ".mp4"], binmode: true)
    screenshot = Tempfile.new(["screenshot", ".jpg"], binmode: true)

    movie = FFMPEG::Movie.new(mov.path)
    movie.transcode(transcoded.path)
    movie.screenshot(screenshot.path)

    [transcoded, screenshot].each(&:open) # refresh file descriptors
    original.close!

    { original: io, transcoded: transcoded, screenshot: screenshot }
  end
end
```

## On-the-fly processing

Generating image thumbnails on upload can be a pain to maintain, because
whenever you need to add a new version or change an existing one, you need to
perform this change for all existing uploads. [This guide][reprocessing
versions] explains the process in more detail.

As an alternative, it's very common to generate thumbnails dynamically, when
their URL is first requested, and then cache the processing result for future
requests. This strategy is known as "on-the-fly processing", and it's suitable
for smaller files such as images.

Shrine doesn't ship with on-the-fly processing functionality, as that's a
separate responsibility that belongs in its own project. There are various
open source solutions that provide this functionality:

* [Dragonfly]
* [imgproxy]
* [imaginary]
* [thumbor]
* [flyimg]
* ...

as well as many commercial solutions. To prove that you can really use them,
let's see how we can hook up [Dragonfly] with Shrine. We'll also see how we
can use [Cloudinary], as an example of a commercial solution.

### Dragonfly

Dragonfly is a mature file attachment library that comes with functionality for
on-the-fly processing. At first it might appear that Dragonfly can only be used
as an alternative to Shrine, but Dragonfly's app that performs on-the-fly
processing can actually be used standalone.

To set up Dragonfly, we'll insert its middleware that serves files and add
basic [configuration][Dragonfly configuration]:

```rb
Dragonfly.app.configure do
  url_format "/attachments/:job"
  secret "my secure secret" # used to generate the protective SHA
  plugin :imagemagick
end

use Dragonfly::Middleware
```

If you're storing files in a cloud service like AWS S3, you should give them
public access so that you can generate non-expiring URLs. This way Dragonfly
URLs will not change and thus be cacheable, without having to use Dragonfly's
own S3 data store which requires pulling in [fog-aws].

To give new S3 objects public access, add `{ acl: "public-read" }` to upload
options (note that any existing S3 objects' ACLs will have to be manually
updated):

```rb
Shrine::Storage::S3.new(upload_options: { acl: "public-read" }, **other_options)
# ...
Shrine.plugin :default_url_options, cache: { public: true }, store: { public: true }
```

Now you can generate Dragonfly URLs from `Shrine::UploadedFile` objects:

```rb
def thumbnail_url(uploaded_file, dimensions)
  Dragonfly.app
    .fetch(uploaded_file.url)
    .thumb(dimensions)
    .url
end
```
```rb
thumbnail_url(photo.image, "500x400") #=> "/attachments/W1siZnUiLCJodHRwOi8vd3d3LnB1YmxpY2RvbWFpbn..."
```

### Cloudinary

[Cloudinary] is a nice service for on-the-fly image processing. The
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

[`Shrine::UploadedFile`]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/Base/FileMethods.html
[image_optim]: https://github.com/toy/image_optim
[ImageProcessing]: https://github.com/janko-m/image_processing
[`ImageProcessing::MiniMagick`]: https://github.com/janko-m/image_processing/blob/master/doc/minimagick.md
[ImageMagick]: https://www.imagemagick.org
[GraphicsMagick]: http://www.graphicsmagick.org
[libvips]: http://jcupitt.github.io/libvips/
[Why is libvips quick]: https://github.com/jcupitt/libvips/wiki/Why-is-libvips-quick
[ImageOptim.com]: https://imageoptim.com/api
[Down]: https://github.com/janko-m/down
[HTTP.rb]: https://github.com/httprb/http
[streamio-ffmpeg]: https://github.com/streamio/streamio-ffmpeg
[reprocessing versions]:http://shrinerb.com/rdoc/files/doc/regenerating_versions_md.html
[Dragonfly]: http://markevans.github.io/dragonfly/
[imgproxy]: https://github.com/DarthSim/imgproxy
[imaginary]: https://github.com/h2non/imaginary
[thumbor]: http://thumbor.org
[flyimg]: http://flyimg.io
[Cloudinary]: https://cloudinary.com
[Dragonfly configuration]: http://markevans.github.io/dragonfly/configuration
[fog-aws]: https://github.com/fog/fog-aws
[shrine-cloudinary]: https://github.com/shrinerb/shrine-cloudinary
