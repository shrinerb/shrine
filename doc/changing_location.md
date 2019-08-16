# Changing Location

This guide provides tips for changing location of uploaded files in production,
with zero downtime.

The examples will use the [Sequel] ORM, but it should easily translate to
Active Record. Let's assume we have a `Photo` model with an `image` attachment:

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

## 1. Updating location generation

Since Shrine generates location only once during upload, it is safe to change
the `Shrine#generate_location` method, all existing files will still continue
to work.

```rb
class ImageUploader < Shrine
  def generate_location(io, **options)
    # change location generation
  end
end
```

We can now deploy this change.

## 2. Moving existing files

To move existing files to new location, we can run the following script:

```rb
Photo.paged_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored? # move only attachments uploaded to permanent storage

  old_attacher = attacher.dup

  attacher.set             attacher.upload(attacher.file)                    # reupload file
  attacher.set_derivatives attacher.upload_derivatives(attacher.derivatives) # reupload derivatives

  begin
    attacher.atomic_persist # persist changes if attachment has not changed in the meantime
    old_attacher.destroy    # delete files on old location
  rescue Shrine::AttachmentChanged, # attachment has changed
         Sequel::NoExistingObject   # record has been deleted
    attacher.destroy # delete now orphaned files
  end
end
```

Now all your existing attachments should be happily living on new locations.

[Sequel]: http://sequel.jeremyevans.net/
