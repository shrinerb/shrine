---
title: Mirroring
---

The [`mirroring`][mirroring] plugin enables replicating uploads and deletes to
other storages. This can be useful for setting up a backup storage, or when
migrating files from one storage to another.

```rb
Shrine.plugin :mirroring, mirror: { store: :other_store }
```

With the above setup, any upload and delete to `:store` will be replicated to
`:other_store`.

```rb
file = Shrine.upload(io, :store) # uploads to :store and :other_store
file.delete                      # deletes from :store and :other_store
```

You can skip mirroring for a specific upload/delete call by passing `mirror:
false`:

```rb
file = Shrine.upload(io, :store, mirror: false) # skips mirroring
file.delete(mirror: false)                      # skips mirroring
```

## Multiple storages

You can mirror to multiple storages by specifying an array:

```rb
Shrine.plugin :mirroring, mirror: {
  store: [:other_store_1, :other_store_2]
}
```

## Backup storage

If you want the mirror storage to act as a backup, you can disable mirroring
deletes:

```rb
Shrine.plugin :mirroring, mirror: { ... }, delete: false
```

## Backgrounding

You can have mirroring performed in a background job:

```rb
Shrine.mirror_upload_block do |file, **options|
  MirrorUploadJob.perform_async(file.shrine_class.name, file.data)
end

Shrine.mirror_delete_block do |file|
  MirrorDeleteJob.perform_async(file.shrine_class.name, file.data)
end
```
```rb
class MirrorUploadJob
  include Sidekiq::Worker

  def perform(shrine_class, file_data)
    shrine_class = Object.const_get(shrine_class)

    file = shrine_class.uploaded_file(file_data)
    file.mirror_upload
  end
end
```
```rb
class MirrorDeleteJob
  include Sidekiq::Worker

  def perform(shrine_class, file_data)
    shrine_class = Object.const_get(shrine_class)

    file = shrine_class.uploaded_file(file_data)
    file.mirror_delete
  end
end
```

## API

You can disable automatic mirroring and perform mirroring manually:

```rb
# disable automatic mirroring of uploads and deletes
Shrine.plugin :mirroring, mirror: { ... }, upload: false, delete: false
```

To perform mirroring, you can call `UploadedFile#mirror_upload` and
`UploadedFile#mirror_delete`:

```rb
file = Shrine.upload(io, :store) # upload to :store
file.mirror_upload               # upload to :other_store

file.delete                      # delete from :store
file.mirror_delete               # delete from :other_store
```

If you've set up backgrounding, you can use
`UploadedFile#mirror_upload_background` and
`UploadedFile#mirror_delete_background` to call the background block instead:

```rb
file = Shrine.upload(io, :store) # upload to :store
file.mirror_upload_background    # spawn mirror upload background job

file.delete                      # delete from :store
file.mirror_delete_background    # spawn mirror delete background job
```

[mirroring]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/mirroring.rb
