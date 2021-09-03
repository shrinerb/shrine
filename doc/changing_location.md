---
id: changing-location
title: Migrating File Locations
---

This guide shows how to migrate the location of uploaded files on the same 
storage in production, with zero downtime.

Let's assume we have a `Photo` model with an `image` file attachment:

```rb
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

## 1. Update the location generation

Since Shrine generates the location only once during upload, it is safe to change
the `Shrine#generate_location` method. All the existing files will still continue
to work with the previously stored urls because the files have not been migrated.

```rb
class ImageUploader < Shrine
  def generate_location(io, **options)
    # change location generation
  end
end
```

We can now deploy this change to production so new file uploads will be stored in 
the new location.

## 2. Move existing files

To move existing files to new location, run the following script. It fetches
the photos in batches, downloads the image, and re-uploads it to the new location.
We only need to migrate the files in `:store` storage need to be migrated as the files
in `:cache` storage will be uploaded to the new location on promotion.

```rb
Photo.find_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored? # move only attachments uploaded to permanent storage

  old_attacher = attacher.dup
  current_file = old_attacher.file

  attacher.set             attacher.upload(attacher.file)                    # reupload file
  attacher.set_derivatives attacher.upload_derivatives(attacher.derivatives) # reupload derivatives if you have derivatives

  begin
    attacher.atomic_persist(current_file) # persist changes if attachment has not changed in the meantime
    old_attacher.destroy_attached         # delete files on old location
  rescue Shrine::AttachmentChanged,       # attachment has changed during reuploading
         ActiveRecord::RecordNotFound     # record has been deleted during reuploading
    attacher.destroy_attached             # delete now orphaned files
  end
end
```

Now all your existing attachments should be happily living on new locations.

### Backgrounding

For faster migration, we can also delay moving files into a background job:

```rb
Photo.find_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored? # move only attachments uploaded to permanent storage

  MoveFilesJob.perform_async(
    attacher.class.name,
    attacher.record.class.name,
    attacher.record.id,
    attacher.name,
    attacher.file_data,
  )
end
```
```rb
class MoveFilesJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher     = attacher_class.retrieve(model: record, name: name, file: file_data)
    old_attacher = attacher.dup
    current_file = old_attacher.file

    attacher.set             attacher.upload(attacher.file)
    attacher.set_derivatives attacher.upload_derivatives(attacher.derivatives)

    attacher.atomic_persist(current_file)
    old_attacher.destroy_attached
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    attacher&.destroy_attached
  end
end
```
