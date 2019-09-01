# Mirroring

The [`mirroring`][mirroring] plugin enables replicating uploads and deletes to
other storages. This can be useful for setting up a backup storage, or when
migrating files from one storage to another.

```rb
Shrine.plugin :mirroring, mirror: { store: :other_store }
```

With the above setup, any upload and delete to `:store` will be replicated to
`:other_store`.

```rb
uploaded_file = Shrine.upload(io, :store) # uploads to :store and :other_store
uploaded_file.delete                      # deletes from :store and :other_store
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
Shrine.mirror_upload do |uploaded_file|
  MirrorUploadJob.perform_async(uploaded_file.shrine_class, uploaded_file.data)
end

Shrine.mirror_delete do |uploaded_file|
  MirrorDeleteJob.perform_async(uploaded_file.shrine_class, uploaded_file.data)
end
```
```rb
class MirrorUploadJob
  include Sidekiq::Worker
  def perform(shrine_class, file_data)
    uploaded_file = Object.const_get(shrine_class).uploaded_file(file_data)
    uploaded_file.mirror_upload
  end
end
```
```rb
class MirrorDeleteJob
  include Sidekiq::Worker
  def perform(shrine_class, file_data)
    uploaded_file = Object.const_get(shrine_class).uploaded_file(file_data)
    uploaded_file.mirror_delete
  end
end
```

## API

You can mirror manually via `UploadedFile#mirror_upload` and
`UploadedFile#mirror_delete`:

```rb
# disable automatic mirroring of uploads and deletes
Shrine.plugin :mirroring, mirror: { ... }, upload: false, delete: false
```
```rb
file = Shrine.upload(io, :store) # upload to :store
file.mirror_upload               # upload to :other_store

file.delete                      # delete from :store
file.mirror_delete               # delete from :other_store
```

[mirroring]: /lib/shrine/plugins/mirroring.rb
