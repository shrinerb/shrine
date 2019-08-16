# Changing Derivatives

This guide provides tips for modifying [derivatives] logic for an app that is
already live and handling file attachments, with zero downtime.

The examples will be showing image thumbnails (`Photo` model with `image`
attachment), but the advice applies to any kind of derivatives. We'll also be
using the [Sequel] ORM, but it should easily translate to Active Record.

```rb
Shrine.plugin :sequel
```
```rb
class ImageUploader < Shrine
  # ...
end
```
```rb
class Photo < Sequel::Model
  include ImageUploader::Attachment(:image)
end
```

## Contents

* [Introducing derivatives](#introducing-derivatives)
* [Reprocessing all derivatives](#reprocessing-all-derivatives)
* [Reprocessing certain derivatives](#reprocessing-certain-derivatives)
* [Adding derivatives](#adding-derivatives)
* [Removing derivatives](#removing-derivatives)

## Introducing derivatives

*Scenario: Your app is currently working only with original files, and you want
to introduce derivatives.*

Start by loading the `derivatives` plugin and defining your processing logic:

```rb
# Gemfile
gem "image_processing", "~> 1.2"
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :derivatives

  Attacher.derivatives_processor :thumbnails do |original|
    processor = ImageProcessing::MiniMagick.source(original)

    # generate the thumbnails you want here
    {
      small:  processor.resize_to_limit!(300, 300),
      medium: processor.resize_to_limit!(500, 500),
      large:  processor.resize_to_limit!(800, 800),
    }
  end
end
```

Note that we cannot update our attachment URLs yet, because only new
attachments will have thumbnails generated, existing attachments will still
have only the original file. So we can go ahead and deploy this change.

Next, we want to generate derivatives for all existing attachments in
production. We can do this by running the following script:

```rb
Photo.paged_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored? # reprocess only attachments uploaded to permanent storage

  attacher.create_derivatives(:thumbnails)

  begin
    attacher.atomic_persist # persist changes if attachment has not changed in the meantime
  rescue Shrine::AttachmentChanged, # attachment has changed
         Sequel::NoExistingObject   # record has been deleted
    attacher.delete_derivatives # delete now orphaned derivatives
  end
end
```

Now all attachments should have correctly generated derivatives

## Reprocessing all derivatives

*Scenario: The processing logic has changed for all derivatives, and now you
want to reprocess them for existing attachments.*

Once the processing logic change has been deployed, we can run the following
script to reprocess all derivatives:

```rb
Photo.paged_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored?

  old_derivatives = attacher.derivatives

  attacher.set_derivatives({}) # clear derivatives
  attacher.create_derivatives(:thumbnails) # reprocess derivatives

  begin
    attacher.atomic_persist # persist changes if attachment has not changed in the meantime
    attacher.delete_derivatives(old_derivatives) # delete old derivatives
  rescue Shrine::AttachmentChanged, # attachment has changed
         Sequel::NoExistingObject   # record has been deleted
    attacher.delete_derivatives # delete now orphaned derivatives
  end
end
```

## Reprocessing certain derivatives

*Scenario: The processing logic has changed for specific derivatives, and now
you want to reprocess them for existing attachments.*

Let's assume we've deployed the following change:

```diff
Attacher.derivatives_processor :thumbnails do |original|
  processor = ImageProcessing::MiniMagick.source(original)

  {
    small:  processor.resize_to_limit!(300, 300),
-   medium: processor.resize_to_limit!(500, 500),
+   medium: processor.resize_to_limit!(600, 600),
    large:  processor.resize_to_limit!(800, 800),
  }
end
```

We can run the following script to reprocess the derivative:

```rb
Photo.paged_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.derivatives.key?(:medium)

  old_medium = attacher.derivatives[:medium]
  new_medium = attacher.file.download do |original|
    ImageProcessing::MiniMagick
      .source(original)
      .resize_to_limit!(600, 600)
  end

  attacher.add_derivative(:medium, new_medium)

  begin
    attacher.atomic_persist # persist changes if attachment has not changed in the meantime
    old_medium.delete
  rescue Shrine::AttachmentChanged, # attachment has changed
         Sequel::NoExistingObject   # record has been deleted
    attacher.derivatives[:medium].delete # delete now orphaned derivative
  end
end
```

## Adding derivatives

*Scenario: A new derivative has been added to the processor, and now
you want to add it to existing attachments.*

Let's assume we've deployed the following change:

```diff
Attacher.derivatives_processor :thumbnails do |original|
  processor = ImageProcessing::MiniMagick.source(original)

  {
    small:   processor.resize_to_limit!(300,  300),
    medium:  processor.resize_to_limit!(600,  600),
    large:   processor.resize_to_limit!(800,  800),
+   x_large: processor.resize_to_limit!(1200, 1200),
  }
end
```

We can now run the following script to add the new derivative:

```rb
Photo.paged_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored?

  x_large = attacher.file.download do |original|
    ImageProcessor::MiniMagick
      .source(original)
      .resize_to_limit!(1200, 1200)
  end

  attacher.add_derivative(:x_large, x_large)

  begin
    attacher.atomic_persist # persist changes if attachment has not changed in the meantime
  rescue Shrine::AttachmentChanged, # attachment has changed
         Sequel::NoExistingObject   # record has been deleted
    attacher.derivatives[:x_large].delete # delete now orphaned derivative
  end
end
```

Now all attachments should have the new derivative and you can start generating
URLs for it.

## Removing derivatives

*Scenario: A derivative isn't being used anymore, so we want to delete it for
existing attachments.*

Let's say we've deployed the following change:

```diff
Attacher.derivatives_processor :thumbnails do |original|
  processor = ImageProcessing::MiniMagick.source(original)

  {
    small:   processor.resize_to_limit!(300,  300),
    medium:  processor.resize_to_limit!(600,  600),
    large:   processor.resize_to_limit!(800,  800),
-   x_large: processor.resize_to_limit!(1200, 1200),
  }
end
```

Now we can run the following script to remove the unused derivative:

```rb
Photo.paged_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.derivatives.key?(:x_large)

  x_large = attacher.remove_derivative(:x_large)

  begin
    attacher.atomic_persist # persist changes if attachment has not changed in the meantime
    x_large.delete
  rescue Shrine::AttachmentChanged, # attachment has changed
         Sequel::NoExistingObject   # record has been deleted
  end
end
```

[derivatives]: /doc/plugins/derivatives.md#readme
[Sequel]: http://sequel.jeremyevans.net/
