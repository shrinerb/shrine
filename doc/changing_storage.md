# Migrating File Storage

This guides shows how to move file attachments to a different storage in 
production, with zero downtime.

_Note: The examples use the [Sequel] ORM, but it should easily translate to
Active Record._

Let's assume we have a `Photo` model with an `image` file attachment stored
in AWS S3 storage:

```rb
Shrine.plugin :sequel
Shrine.storages = {
  cache: Shrine::Storage::S3.new(...),
  store: Shrine::Storage::S3.new(...),
}
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

Let's also assume we're migrating from AWS S3 to Google Cloud Storage. We will use
a `new_storage` local variable to hold the new storage object whenever we need:

```rb
new_storage = Shrine::Storage::GoogleCloudStorage.new(...)
```

## 1. Mirror upload and delete operations

The first step is to start mirroring uploads and deletes made on your current
storage to the new storage. We can do this by subscribing to upload and delete
events using the `instrumentation` plugin:

```rb
Shrine.plugin :instrumentation

Shrine.subscribe(:upload) do |event|
  next unless event[:storage] == :store # mirror only uploads on permanent storage

  file = Shrine.uploaded_file(storage: event[:storage], id: event[:location])

  new_storage = Shrine::Storage::GoogleCloudStorage.new(...)
  new_storage.upload(file, file.id, shrine_metadata: event[:metadata])
end

Shrine.subscribe(:delete) do |event|
  next unless event[:storage] == :store # mirror only deletes on permanent storage

  new_storage = Shrine::Storage::GoogleCloudStorage.new(...)
  new_storage.delete(event[:location])
end
```

Put the above code in an initializer and deploy it.

## 2. Copy the files

Next step is to copy all remaining files from current storage into the new
storage using the following script. It fetches the photos in batches, downloads 
the image, and re-uploads it to the new storage. 

```rb
Photo.paged_each do |photo|
  attacher = photo.image_attacher

  next unless attacher.stored?

  files = [attacher.file]
  new_storage = Shrine::Storage::GoogleCloudStorage.new(...)

  # if using derivatives
  attacher.map_derivative(attacher.derivatives) do |path, derivative|
    files << derivative
  end

  # stores the files in same location on new storage
  files.each do |file|
    new_storage.upload(file, file.id, shrine_metadata: file.metadata)
  end
end
```

Now the new storage should have all files the current storage has, and new
uploads will continue being mirrored to the new storage.

## 3. Updating storage

Once all the files are copied over to the new storage, everything is ready 
for us to change the storage in the Shrine configuration:

```diff
Shrine.storages = {
  cache: Shrine::Storage::S3.new(...),
- store: Shrine::Storage::S3.new(...),
+ store: Shrine::Storage::GoogleCloudStorage.new(...),
}
```

## 4. Remove the mirroring operations

Remove the mirroring upload and delete operations code we created in step 1 
and deploy to production.

[Sequel]: http://sequel.jeremyevans.net/
