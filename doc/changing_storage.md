# Changing Storage

This guides provides tips for moving attachments to a different storage when
your app is live in production, with zero downtime.

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

Let's also assume that we're migrating from AWS S3 to Google Cloud Storage, and
that the `new_storage` local variable holds the new storage object:

```rb
new_storage = Shrine::Storage::GoogleCloudStorage.new(...)
```

## 1. Mirroring operations

The first step is to start mirroring uploads and deletes made on your current
storage to the new storage. We can do this by subscribing to upload and delete
events:

```rb
Shrine.plugin :instrumentation

Shrine.subscribe(:upload) do |event|
  next unless event[:storage] == :store # mirror only uploads on permanent storage

  file = Shrine.uploaded_file(storage: event[:storage], id: event[:location])

  new_storage.upload(file, file.id, shrine_metadata: event[:metadata])
end

Shrine.subscribe(:delete) do |event|
  next unless event[:storage] == :store # mirror only deletes on permanent storage

  new_storage.delete(event[:location])
end
```

We can put the above code in an initializer and deploy it.

## 2. Copying files

Next step is to copy all remaining files from current storage into the new
storage. We can do this by running the following script:

```rb
Photo.paged_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored?

  files = [attacher.file]

  # if using derivatives
  attacher.map_derivative(attacher.derivatives) do |path, derivative|
    files << derivative
  end

  files.each do |file|
    new_storage.upload(file, file.id, shrine_metadata: file.metadata)
  end
end
```

Now the new storage should have all files the current storage has, and new
uploads will continue being mirrored to the new storage.

## 3. Updating storage

Now everything should be ready for us to simply change the storage in the
Shrine configuration:

```diff
Shrine.storages = {
  cache: Shrine::Storage::S3.new(...),
- store: Shrine::Storage::S3.new(...),
+ store: Shrine::Storage::GoogleCloudStorage.new(...),
}
```

You should now also be able to remove the mirroring code.
