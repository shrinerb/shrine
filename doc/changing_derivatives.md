---
id: changing-derivatives
title: Managing Derivatives
---

This guide shows how to add, create, update, and remove [derivatives] for an 
app in production already handling file attachments, with zero downtime.

Let's assume we have a `Photo` model with an `image` file attachment. The 
examples will be showing image thumbnails, but the advice applies to any kind 
of derivatives. 

```rb
Shrine.plugin :derivatives
Shrine.plugin :activerecord
```
```rb
class ImageUploader < Shrine
  # ...
end
```
```rb
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment(:image)
end
```

## Adding derivatives

*Scenario: Your app is currently working only with original files, and you want
to introduce derivatives.*

You'll first want to start creating the derivatives in production, without yet
generating URLs for them (because existing attachments won't yet have
derivatives generated). Let's assume you're generating image thumbnails:

```rb
# Gemfile
gem "image_processing", "~> 1.8"
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  Attacher.derivatives_processor do |original|
    magick = ImageProcessing::MiniMagick.source(original)

    # generate the thumbnails you want here
    {
      small:  magick.resize_to_limit!(300, 300),
      medium: magick.resize_to_limit!(500, 500),
      large:  magick.resize_to_limit!(800, 800),
    }
  end
end
```
```rb
photo = Photo.new(photo_params)
photo.image_derivatives! # generate derivatives
photo.save
```

Once we've deployed this to production, we can run the following script to
generate derivatives for all existing attachments in production. It fetches the
records in batches, downloads attachments on permanent storage, creates
derivatives, and persists the changes.

```rb
Photo.find_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored?

  attacher.create_derivatives

  begin
    attacher.atomic_persist            # persist changes if attachment has not changed in the meantime
  rescue Shrine::AttachmentChanged,    # attachment has changed
         ActiveRecord::RecordNotFound  # record has been deleted
    attacher.delete_derivatives        # delete now orphaned derivatives
  end
end
```

Now all attachments should have correctly generated derivatives. You can update
the attachment URLs to use derivatives as needed.

## Reprocessing all derivatives

*Scenario: The processing logic has changed for all or most derivatives, and
now you want to reprocess them for existing attachments.*

Let's assume we've made the following change and have deployed it to production:

```diff
Attacher.derivatives_processor do |original|
  magick = ImageProcessing::MiniMagick.source(original)
+   .saver(quality: 85)

  {
    small:  magick.resize_to_limit!(300, 300),
    medium: magick.resize_to_limit!(500, 500),
    large:  magick.resize_to_limit!(800, 800),
  }
end
```

We can now run the following script to reprocess derivatives for all existing
records. It fetches the records in batches, downloads attachments on permanent
storage, reprocesses new derivatives, persists the changes, and deletes old
derivatives. 

```rb
Photo.find_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored?

  old_derivatives = attacher.derivatives

  attacher.set_derivatives({})                    # clear derivatives
  attacher.create_derivatives                     # reprocess derivatives

  begin
    attacher.atomic_persist                       # persist changes if attachment has not changed in the meantime
    attacher.delete_derivatives(old_derivatives)  # delete old derivatives
  rescue Shrine::AttachmentChanged,               # attachment has changed
         ActiveRecord::RecordNotFound             # record has been deleted
    attacher.delete_derivatives                   # delete now orphaned derivatives
  end
end
```

## Reprocessing certain derivatives

*Scenario: The processing logic has changed for specific derivatives, and now
you want to reprocess them for existing attachments.*

Let's assume we've made a following change and have deployed it to production:

```diff
Attacher.derivatives_processor do |original|
  magick = ImageProcessing::MiniMagick.source(original)

  {
    small:  magick.resize_to_limit!(300, 300),
-   medium: magick.resize_to_limit!(500, 500),
+   medium: magick.resize_to_limit!(600, 600),
    large:  magick.resize_to_limit!(800, 800),
  }
end
```

We can now run the following script to reprocess the derivative for all
existing records. It fetches the records in batches, downloads attachments with
derivatives, reprocesses the specific derivative, persists the change, and
deletes old derivative.

```rb
Photo.find_each do |photo|
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
    attacher.atomic_persist               # persist changes if attachment has not changed in the meantime
    old_medium.delete                     # delete old derivative
  rescue Shrine::AttachmentChanged,       # attachment has changed
         ActiveRecord::RecordNotFound     # record has been deleted
    attacher.derivatives[:medium].delete  # delete now orphaned derivative
  end
end
```

## Adding new derivatives

*Scenario: A new derivative has been added to the processor, and now
you want to add it to existing attachments.*

Let's assume we've made a following change and have deployed it to production:

```diff
Attacher.derivatives_processor do |original|
  magick = ImageProcessing::MiniMagick.source(original)

  {
+   square: magick.resize_to_fill!(150, 150),
    small:  magick.resize_to_limit!(300, 300),
    medium: magick.resize_to_limit!(600, 600),
    large:  magick.resize_to_limit!(800, 800),
  }
end
```

We can now run following script to add the new derivative for all existing
records. It fetches the records in batches, downloads attachments on permanent
storage, creates the new derivative, and persists the changes.

```rb
Photo.find_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored?

  square = attacher.file.download do |original|
    ImageProcessor::MiniMagick
      .source(original)
      .resize_to_fill!(150, 150)
  end

  attacher.add_derivative(:square, square)

  begin
    attacher.atomic_persist               # persist changes if attachment has not changed in the meantime
  rescue Shrine::AttachmentChanged,       # attachment has changed
         ActiveRecord::RecordNotFound     # record has been deleted
    attacher.derivatives[:square].delete  # delete now orphaned derivative
  end
end
```

Now all attachments should have the new derivative and you can start generating
URLs for it.

## Removing derivatives

*Scenario: A derivative isn't being used anymore, so we want to delete it for
existing attachments.*

Let's assume we've made the following change and have deployed it to production:

```diff
Attacher.derivatives_processor do |original|
  magick = ImageProcessing::MiniMagick.source(original)

  {
-   square: magick.resize_to_fill!(150, 150),
    small:  magick.resize_to_limit!(300, 300),
    medium: magick.resize_to_limit!(600, 600),
    large:  magick.resize_to_limit!(800, 800),
  }
end
```

We can now run following script to remove the unused derivative for all
existing record. It fetches the records in batches, removes and deletes the
unused derivative, and persists the changes.

```rb
Photo.find_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.derivatives.key?(:square)

  attacher.remove_derivative(:square, delete: true)

  begin
    attacher.atomic_persist            # persist changes if attachment has not changed in the meantime
  rescue Shrine::AttachmentChanged,    # attachment has changed
         ActiveRecord::RecordNotFound  # record has been deleted
  end
end
```

## Backgrounding

For faster migration, we can also delay any of the operations above into a
background job:

```rb
Photo.find_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored?

  MakeChangeJob.perform_async(
    attacher.class.name,
    attacher.record.class.name,
    attacher.record.id,
    attacher.name,
    attacher.file_data,
  )
end
```
```rb
class MakeChangeJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    # ... make our change ...
  end
end
```

[derivatives]: https://shrinerb.com/docs/plugins/derivatives
