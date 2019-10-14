---
id: changing-storage
title: Migrating File Storage
---

This guides shows how to move file attachments to a different storage in 
production, with zero downtime.

Let's assume we have a `Photo` model with an `image` file attachment stored
in AWS S3 storage:

```rb
Shrine.storages = {
  cache: Shrine::Storage::S3.new(...),
  store: Shrine::Storage::S3.new(...),
}

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

Let's also assume that we're migrating from AWS S3 to Google Cloud Storage, and
we've added the new storage to `Shrine.storages`:

```rb
Shrine.storages = {
  ...
  store: Shrine::Storage::S3.new(...),
  gcs:   Shrine::Storage::GoogleCloudStorage.new(...),
}
```

## 1. Mirror upload and delete operations

The first step is to start mirroring uploads and deletes made on your current
storage to the new storage. We can do this by loading the `mirroring` plugin:

```rb
Shrine.plugin :mirroring, mirror: { store: :gcs }
```

Put the above code in an initializer and deploy it.

You can additionally delay the mirroring into a [background job][mirroring
backgrounding] for better performance.

## 2. Copy the files

Next step is to copy all remaining files from current storage into the new
storage using the following script. It fetches the photos in batches, downloads 
the image, and re-uploads it to the new storage. 

```rb
Photo.find_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored?

  attacher.file.trigger_mirror_upload

  # if using derivatives
  attacher.map_derivative(attacher.derivatives) do |_, derivative|
    derivative.trigger_mirror_upload
  end
end
```

Now the new storage should have all files the current storage has, and new
uploads will continue being mirrored to the new storage.

## 3. Update storage

Once all the files are copied over to the new storage, everything should be
ready for us to update the storage in the Shrine configuration. We can keep
mirroring, in case the change would need to reverted.

```rb
Shrine.storages = {
  ...
  store: Shrine::Storage::GoogleCloudStorage.new(...),
  s3:    Shrine::Storage::S3.new(...),
}

Shrine.plugin :mirroring, mirror: { store: :s3 } # mirror to :s3 storage
```

## 4. Remove mirroring

Once everything is looking good, we can remove the mirroring:

```diff
Shrine.storages = {
  ...
  store: Shrine::Storage::GoogleCloudStorage.new(...),
- s3:    Shrine::Storage::S3.new(...),
}

- Shrine.plugin :mirroring, mirror: { store: :s3 } # mirror to :s3 storage
```

[mirroring backgrounding]: https://shrinerb.com/docs/plugins/mirroring#backgrounding
