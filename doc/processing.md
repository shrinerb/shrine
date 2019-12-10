---
title: File Processing
---

Shrine allows you to process attached files eagerly or on-the-fly. For
example, if your app is accepting image uploads, you can generate a predefined
set of of thumbnails when the image is attached to a record, or you can have
thumbnails generated dynamically as they're needed.

How you're going to implement processing is entirely up to you. For images it's
recommended to use the **[ImageProcessing]** gem, which provides wrappers for
processing with [MiniMagick][ImageProcessing::MiniMagick] and
[libvips][ImageProcessing::Vips]. Here is an example of generating a thumbnail
with ImageProcessing:

```
$ brew install imagemagick
```
```rb
# Gemfile
gem "image_processing", "~> 1.8"
```
```rb
require "image_processing/mini_magick"

thumbnail = ImageProcessing::MiniMagick
  .source(image)              # input file
  .resize_to_limit(600, 400)  # resize macro
  .colorspace("grayscale")    # custom operation
  .convert("jpeg")            # output type
  .saver(quality: 90)         # output options
  .call                       # run the pipeline

thumbnail #=> #<Tempfile:...> (a 600x400 thumbnail of the source image)
```

## Eager processing

Let's say we're handling images, and want to generate a predefined set of
thumbnails with various dimensions. We can use the
**[`derivatives`][derivatives]** plugin to upload and save the processed files:

```rb
Shrine.plugin :derivatives
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  Attacher.derivatives do |original|
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
photo = Photo.new(image: file)
photo.image_derivatives! # calls derivatives processor
photo.save
```

After the processed files are uploaded, their data is saved into the
`<attachment>_data` column. You can then retrieve the derivatives as
[`Shrine::UploadedFile`] objects:

```rb
photo.image(:large)            #=> #<Shrine::UploadedFile ...>
photo.image(:large).url        #=> "/uploads/store/lg043.jpg"
photo.image(:large).size       #=> 5825949
photo.image(:large).mime_type  #=> "image/jpeg"
```

### Conditional derivatives

The `Attacher.derivatives` block is evaluated in context of a
`Shrine::Attacher` instance:

```rb
Attacher.derivatives do |original|
  self    #=> #<Shrine::Attacher>

  file    #=> #<Shrine::UploadedFile>
  record  #=> #<Photo>
  name    #=> :image
  context #=> { ... }

  # ...
end
```

This gives you the ability to branch the processing logic based on the
attachment information:

```rb
Attacher.derivatives do |original|
  magick = ImageProcessing::MiniMagick.source(original)
  result = {}

  if record.is_a?(Photo)
    result[:jpg]  = magick.convert!("jpeg")
    result[:gray] = magick.colorspace!("grayscale")
  end

  if file.mime_type == "image/svg+xml"
    result[:png] = magick.loader(transparent: "white").convert!("png")
  end

  result
end
```

If you find yourself branching a lot based on MIME type, the
[`type_predicates`][type_predicates] plugin provides convenient predicate
methods for that.

### Backgrounding

Since file processing can be time consuming, it's recommended to move it into a
background job.

#### A) Creating derivatives with promotion

The simplest way is to use the [`backgrounding`][backgrounding] plugin to move
promotion into a background job, and then create derivatives as part of
promotion:

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
    attacher.create_derivatives # calls derivatives processor
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    # attachment has changed or the record has been deleted, nothing to do
  end
end
```

#### B) Creating derivatives separately from promotion

Derivatives don't need to be created as part of the attachment flow, you can
create them at any point after promotion:

```rb
DerivativesJob.perform_async(
  attacher.class.name,
  attacher.record.class.name,
  attacher.record.id,
  attacher.name,
  attacher.file_data,
)
```
```rb
class DerivativesJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.create_derivatives # calls derivatives processor
    attacher.atomic_persist
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    attacher&.destroy_attached # delete now orphaned derivatives
  end
end
```

#### C) Creating derivatives concurrently

You can also generate derivatives concurrently:

```rb
class ImageUploader < Shrine
  THUMBNAILS = {
    large:  [800, 800],
    medium: [500, 500],
    small:  [300, 300],
  }

  Attacher.derivatives do |original, name:|
    thumbnail = ImageProcessing::MiniMagick
      .source(original)
      .resize_to_limit!(*THUMBNAILS.fetch(name))

    { name => thumbnail }
  end
end
```
```rb
ImageUploader::THUMBNAILS.each_key do |derivative_name|
  DerivativeJob.perform_async(
    attacher.class.name,
    attacher.record.class.name,
    attacher.record.id,
    attacher.name,
    attacher.file_data,
    derivative_name,
  )
end
```
```rb
class DerivativeJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data, derivative_name)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.create_derivatives(name: derivative_name)
    attacher.atomic_persist do |reloaded_attacher|
      # make sure we don't override derivatives created in other jobs
      attacher.merge_derivatives(reloaded_attacher.derivatives)
    end
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    attacher.derivatives[derivative_name].delete # delete now orphaned derivative
  end
end
```

### URL fallbacks

If you're creating derivatives in a background job, you'll likely want to use
some fallbacks for derivative URLs while the background job is still
processing. You can do that with the [`default_url`][default_url] plugin.

```rb
Shrine.plugin :default_url
```

#### A) Fallback to original

You can fall back to the original file URL when the derivative is missing:

```rb
Attacher.default_url do |derivative: nil, **|
  file&.url if derivative
end
```
```rb
photo.image_url(:large) #=> "https://example.com/path/to/original.jpg"
# ... background job finishes ...
photo.image_url(:large) #=> "https://example.com/path/to/large.jpg"
```

#### B) Fallback to derivative

You can fall back to another derivative URL when the derivative is missing:

```rb
Attacher.default_url do |derivative: nil, **|
  derivatives[:optimized]&.url if derivative
end
```
```rb
photo.image_url(:large) #=> "https://example.com/path/to/optimized.jpg"
# ... background job finishes ...
photo.image_url(:large) #=> "https://example.com/path/to/large.jpg"
```

#### C) Fallback to on-the-fly

You can also fall back to [on-the-fly processing](#on-the-fly-processing),
which should generally provide the best user experience.

```rb
THUMBNAILS = {
  small:  [300, 300],
  medium: [500, 500],
  large:  [800, 800],
}

Attacher.default_url do |derivative: nil, **|
  file&.derivation_url(:thumbnail, *THUMBNAILS.fetch(derivative)) if derivative
end
```
```rb
photo.image_url(:large) #=> "../derivations/thumbnail/800/800/..."
# ... background job finishes ...
photo.image_url(:large) #=> "https://example.com/path/to/large.jpg"
```

## On-the-fly processing

Having eagerly created image thumbnails can be a pain to maintain, because
whenever you need to add a new version or change an existing one, you need to
retroactively apply it to all existing attachments (see the [Managing
Derivatives] guide for more details).

Sometimes it makes more sense to generate thumbnails dynamically as they're
requested, and then cache them for future requests. This strategy is known as
processing "**on-the-fly**" or "**on-demand**", and it's suitable for
short-running processing such as creating image thumbnails or document
previews.

Shrine provides on-the-fly processing functionality via the
**[`derivation_endpoint`][derivation_endpoint]** plugin. You set it up by
loading the plugin with a secret key and a path prefix, mount its Rack app in
your routes on the configured path prefix, and define processing you want to
perform:

```rb
# config/initializers/shrine.rb (Rails)
# ...
Shrine.plugin :derivation_endpoints, secret_key: "<YOUR_SECRET_KEY>"
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :derivation_endpoint, prefix: "derivations/image" # matches mount point

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
  # ...
  mount ImageUploader.derivation_endpoint => "/derivations/image"
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

### Dynamic derivation

If you have multiple types of transformations and don't want to have a
derivation for each one, you can set up a single derivation that applies any
series of transformations:

```rb
class ImageUploader < Shrine
  derivation :transform do |original, transformations|
    transformations = Shrine.urlsafe_deserialize(transformations)

    vips = ImageProcessing::Vips.source(original)
    vips.apply!(transformations)
  end
end
```
```rb
photo.image.derivation_url :transform, Shrine.urlsafe_serialize(
  crop:          [10, 10, 500, 500],
  resize_to_fit: [300, 300],
  gaussblur:     1,
)
```

You can create a helper method for convenience:

```rb
def derivation_url(file, transformations)
  file.derivation_url(:transform, Shrine.urlsafe_serialize(transformations))
end
```
```rb
derivation_url photo.image,
  crop:          [10, 10, 500, 500],
  resize_to_fit: [300, 300],
  gaussblur:     1
```

## Processing other filetypes

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
  Attacher.derivatives do |original|
    transcoded = Tempfile.new ["transcoded", ".mp4"]
    screenshot = Tempfile.new ["screenshot", ".jpg"]

    movie = FFMPEG::Movie.new(original.path)
    movie.transcode(transcoded.path)
    movie.screenshot(screenshot.path)

    { transcoded: transcoded, screenshot: screenshot }
  end
end
```

### Polymorphic uploader

Sometimes you might want an attachment attribute to accept multiple types of
files, and apply different processing depending on the type. Since Shrine's
processing blocks are evaluated dynamically, you can use conditional logic:

```rb
class PolymorphicUploader < Shrine
  IMAGE_TYPES = %w[image/jpeg image/png image/webp]
  VIDEO_TYPES = %w[video/mp4 video/quicktime]
  PDF_TYPES   = %w[application/pdf]

  Attacher.validate do
    validate_mime_type IMAGE_TYPES + VIDEO_TYPES + PDF_TYPES
    # ...
  end

  Attacher.derivatives do |original|
    case file.mime_type
    when *IMAGE_TYPES then process_derivatives(:image, original)
    when *VIDEO_TYPES then process_derivatives(:video, original)
    when *PDF_TYPES   then process_derivatives(:pdf,   original)
    end
  end

  Attacher.derivatives :image do |original|
    # ...
  end

  Attacher.derivatives :video do |original|
    # ...
  end

  Attacher.derivatives :pdf do |original|
    # ...
  end
end
```

## Extras

### Automatic derivatives

If you would like derivatives to be automatically created with promotion, you
can override `Attacher#promote` for call `Attacher#create_derivatives` before
promotion:

```rb
class Shrine::Attacher
  def promote(*)
    create_derivatives
    super
  end
end
```

This shouldn't be needed if you're processing in the
[background](#backgrounding), as in that case you have a background worker that
will be called for each attachment, so you can call
`Attacher#create_derivatives` there.

### libvips

As mentioned, ImageProcessing gem also has an alternative backend for
processing images with **[libvips]**. libvips is a full-featured image
processing library like ImageMagick, with impressive performance
characteristics – it's often **multiple times faster** than ImageMagick and has
low memory usage (see [Why is libvips quick]).

Using libvips is as easy as installing it and switching to the
[`ImageProcessing::Vips`][ImageProcessing::Vips] backend:

```
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

### Parallelize uploads

If you're generating derivatives, you can parallelize the uploads using the
[concurrent-ruby] gem:

```rb
# Gemfile
gem "concurrent-ruby"
```
```rb
require "concurrent"

derivatives = attacher.process_derivatives

tasks = derivatives.map do |name, file|
  Concurrent::Promises.future(name, file) do |name, file|
    attacher.add_derivative(name, file)
  end
end

Concurrent::Promises.zip(*tasks).wait!
```

### External processing

You can also integrate Shrine with 3rd-party processing services such as
[Cloudinary] and [Imgix]. In the most common case, you'd serve images directly
from these services, see the corresponding plugin docs for more details
([shrine-cloudinary], [shrine-imgix] and [others][external storages])

You can also choose to use these services as an implementation detail of your
application, by downloading the processed images and saving them to your
storage. Here is how you might store files processed by Imgix as derivatives:

```rb
# Gemfile
gem "down", "~> 5.0"
gem "http", "~> 4.0"
gem "shrine-imgix", "~> 0.5"
```
```rb
Shrine.plugin :derivatives
Shrine.plugin :imgix, client: { host: "my-app.imgix.net", secure_url_token: "secret" }
```
```rb
require "down/http"

class ImageUploader < Shrine
  IMGIX_THUMBNAIL = -> (file, width, height) do
    Down::Http.download(file.imgix_url(w: width, h: height))
  end

  Attacher.derivatives do
    {
      large:  IMGIX_THUMBNAIL[file, 800, 800],
      medium: IMGIX_THUMBNAIL[file, 500, 500],
      small:  IMGIX_THUMBNAIL[file, 300, 300],
    }
  end
end
```

[`Shrine::UploadedFile`]: http://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html
[ImageProcessing]: https://github.com/janko/image_processing
[ImageProcessing::MiniMagick]: https://github.com/janko/image_processing/blob/master/doc/minimagick.md#readme
[ImageProcessing::Vips]: https://github.com/janko/image_processing/blob/master/doc/vips.md#readme
[streamio-ffmpeg]: https://github.com/streamio/streamio-ffmpeg
[Managing Derivatives]: https://shrinerb.com/docs/changing-derivatives
[Cloudinary]: https://cloudinary.com/
[Imgix]: https://www.imgix.com/
[shrine-cloudinary]: https://github.com/shrinerb/shrine-cloudinary
[shrine-imgix]: https://github.com/shrinerb/shrine-imgix
[backgrounding]: https://shrinerb.com/docs/plugins/backgrounding
[derivation_endpoint]: https://shrinerb.com/docs/plugins/derivation_endpoint
[derivation_endpoint performance]: https://shrinerb.com/docs/plugins/derivation_endpoint#performance
[derivatives]: https://shrinerb.com/docs/plugins/derivatives
[concurrent-ruby]: https://github.com/ruby-concurrency/concurrent-ruby
[default_url]: https://shrinerb.com/docs/plugins/default_url
[external storages]: https://shrinerb.com/docs/external/extensions#storages
[libvips]: https://libvips.github.io/libvips/
[Why is libvips quick]: https://github.com/libvips/libvips/wiki/Why-is-libvips-quick
[type_predicates]: https://shrinerb.com/docs/plugins/type_predicates
