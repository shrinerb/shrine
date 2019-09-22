# File Processing

Shrine allows you to process attached files up front or on-the-fly. For
example, if your app is accepting image uploads, you can generate a predefined
set of of thumbnails when the image is attached to a record, or you can have
thumbnails generated dynamically as they're needed.

How you're going to implement processing is entirely up to you. For images it's
recommended to use the **[ImageProcessing]** gem, which provides wrappers for
processing with [ImageMagick]/[GraphicsMagick] (using the [MiniMagick] gem) or
[libvips] (using the [ruby-vips] gem; see the [libvips section](#libvips)).
Here is an example of generating a thumbnail with ImageProcessing:

```sh
$ brew install imagemagick
```
```rb
# Gemfile
gem "image_processing", "~> 1.8"
```
```rb
require "image_processing/mini_magick"

thumbnail = ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit!(600, 400)

thumbnail #=> #<Tempfile:...> (a 600x400 thumbnail of the source image)
```

## Processing up front

Let's say we're handling images, and want to generate a predefined set of
thumbnails with various dimensions. We can use the `derivatives` plugin to
upload and save the processed files:

```rb
Shrine.plugin :derivatives
```
```rb
require "image_processing/mini_magick"

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
photo = Photo.new
photo.image_derivatives! # calls derivatives processor
photo.save
```

After the processed files are uploaded, their data is saved into the
`<attachment>_data` column. You can then retrieve the derivatives as
[`Shrine::UploadedFile`][uploaded file] objects:

```rb
photo.image(:large)            #=> #<Shrine::UploadedFile ...>
photo.image(:large).url        #=> "/uploads/store/lg043.jpg"
photo.image(:large).size       #=> 5825949
photo.image(:large).mime_type  #=> "image/jpeg"
```

### Backgrounding

Since file processing can be time consuming, it's recommended to move it into a
background job. The simplest way is to use the [`backgrounding`][backgrounding]
plugin to move promotion into a background job, and then create derivatives
as part of promotion:

```rb
Shrine.plugin :backgrounding
Shrine::Attacher.promote_block { PromoteJob.perform_later(self.class, record, name, file_data) }
```
```rb
class PromoteJob < ActiveJob::Base
  def perform(attacher_class, record, name, file_data)
    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.create_derivatives # calls derivatives processor
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    # attachment has changed or the record has been deleted, nothing to do
  end
end
```

Derivatives don't need to be created as part of the attachment flow, you can
create them at any point:

```rb
# ...
DerivativesJob.perform_later(
  attacher.class,
  attacher.record,
  attacher.name,
  attacher.file_data,
)
```
```rb
class DerivativesJob < ActiveJob::Base
  def perform(attacher_class, record, name, file_data)
    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.create_derivatives # calls derivatives processor
    attacher.atomic_persist
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    attacher&.destroy_attached # delete now orphaned derivatives
  end
end
```

### Processing other filetypes

So far we've only been talking about processing images. However, there is
nothing image-specific in Shrine's processing API, you can just as well process
any other types of files. The processing tool doesn't need to have any special
Shrine integration, the ImageProcessing gem that we saw earlier is a completely
generic gem.

To demonstrate, here is an example of transcoding videos using
[streamio-ffmpeg]:

```rb
# Gemfile
gem "streamio-ffmpeg"
```
```rb
require "streamio-ffmpeg"

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

## On-the-fly processing

Generating image thumbnails on upload can be a pain to maintain, because
whenever you need to add a new version or change an existing one, you need to
retroactively apply it to all existing uploads (see the [Managing Derivatives]
guide for more details).

As an alternative, it's very common to instead generate thumbnails dynamically
as they're requested, and then cache them for future requests. This strategy is
known as "on-the-fly processing", and it's suitable for short-running
processing such as creating image thumbnails or document previews.

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
photo.image.derivation_url(:thumbnail, 600, 400)
#=> "/derivations/image/thumbnail/600/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
```

The plugin is highly customizable, be sure to check out the
[documentation][derivation_endpoint], especially the [performance
section][derivation_endpoint performance].

## Extras

### libvips

As mentioned, ImageProcessing gem also has an alternative backend for
processing images with **[libvips]**. libvips is a full-featured image
processing library like ImageMagick, with impressive performance
characteristics – it's often **multiple times faster** than ImageMagick and has
low memory usage (see [Why is libvips quick]).

Using libvips is as easy as installing it and switching to the
`ImageProcessing::Vips` backend:

```sh
$ brew install vips
```

```rb
# Gemfile
gem "image_processing", "~> 1.8"
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
gem "image_processing", "~> 1.8"
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
photo.image_url(width: 100, height: 100, crop: :fit)
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
[Managing Derivatives]: /doc/changing_derivatives.md#readme
[Cloudinary]: https://cloudinary.com
[shrine-cloudinary]: https://github.com/shrinerb/shrine-cloudinary
[backgrounding]: /doc/plugins/backgrounding.md#readme
[ruby-vips]: https://github.com/libvips/ruby-vips
[MiniMagick]: https://github.com/minimagick/minimagick
[derivation_endpoint]: /doc/plugins/derivation_endpoint.md#readme
[derivation_endpoint performance]: /doc/plugins/derivation_endpoint.md#performance
[derivatives]: /doc/plugins/derivatives.md#readme
