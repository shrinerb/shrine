# Atomic Helpers

The [`atomic_helpers`][atomic_helpers] plugin provides API for retrieving and
persisting attachments in a concurrency-safe way, which is useful when using
the `backgrounding` plugin. The database plugins (`activerecord` and `sequel`)
implement atomic promotion and atomic persistence on top of this plugin.

```rb
plugin :atomic_helpers
```

## Retrieving

The `Attacher.retrieve` method provided by the plugin instantiates an attacher
from a record instance, attachment name and attachment data, asserting that the
given attachment data matches the attached file on the record.

```rb
# with a model instance
Shrine::Attacher.retrieve(
  model:  photo,
  name:   :image,
  data:   { "id" => "...", "storage" => "...", "metadata" => { ... } },
)
#=> #<Shrine::Attacher ...>

# with an entity instance
Shrine::Attacher.retrieve(
  entity: photo,
  name:   :image,
  data:   { "id" => "...", "storage" => "...", "metadata" => { ... } },
)
#=> #<Shrine::Attacher ...>
```

If the record has `Shrine::Attachment` included, the `#<name>_attacher` method
will be called on the record, which will return the correct attacher class.

```rb
class Photo
  include ImageUploader::Attachment(:image)
end
```
```rb
Shrine::Attacher.retrieve(model: photo, name: :image, data: { ... })
#=> #<ImageUploader::Attacher ...>
```

Otherwise it will call `Attacher.from_model`/`Attacher.from_entity` from the
`model`/`entity` plugin, in which case you need to make sure to call
`Attacher.retrieve` on the appropriate attacher class.

```rb
ImageUploader::Attacher.retrieve(entity: photo, name: :image, data: { ... })
#=> #<ImageUploader::Attacher ...>
```

If the attached file on the record doesn't match the provided attachment data,
a `Shrine::AttachmentChanged` exception is raised. Note that metadata is
allowed to differ, Shrine will only compare location and storage of the file.

```rb
photo.image_data #=> '{"id":"foo","storage":"cache","metadata":{...}}'

Shrine::Attacher.retrieve(
  model: photo,
  name: :image,
  data: { "id" => "bar", "storage" => "cache", "metadata" => { ... } },
)
# ~> Shrine::AttachmentChanged: attachment has changed
```

## Promoting

The `Attacher#abstract_atomic_promote` method provided by the plugin promotes
the cached file to permanent storage, reloads the record to check whether the
attachment hasn't changed, and if not persists the promoted file.

Internally it calls `Attacher#abstract_atomic_persist` to do the persistence,
forwarding `:reload` and `:persist` options as well as a given block to it (see
the next section for more details).

```rb
# in the controller
attacher.attach_cached(io)
attacher.cached? #=> true

# ...

# in a background job
attacher.abstract_atomic_promote(reload: -> (&block) { ... }, persist: -> { ... })
attacher.stored? #=> true
```

If the attachment has changed during promotion, the promoted file is deleted and
a `Shrine::AttachmentChanged` exception is raised.

Any additional options to `Attacher#abstract_atomic_promote` are forwarded to
`Attacher#promote`.

## Persisting

The `Attacher#abstract_atomic_persist` method reloads the record to check
whether the attachment hasn't changed, and if not persists the attachment.

It requires reloader and persister to be passed in, as they will be specific to
the database library you're using. The reloader needs to call the given block
with the reloaded record, while the persister needs to persist the promoted
file.

```rb
attacher.abstract_atomic_persist(
  reload:  -> (&block) { ... }, # call the block with reloaded record
  persist: -> { ... },          # persist promoted file
)
```

To illustrate, this is how the `Attacher#atomic_promote` method provided by the
`sequel` plugin is implemented:

```rb
attacher.abstract_atomic_persist(
  reload: -> (&block) {
    attacher.record.db.transaction do
      block.call attacher.record.dup.lock! # the DB lock ensures no changes
    end
  },
  persist: -> {
    attacher.record.save_changes(validate: false)
  }
)
```

By default, the file currently set on the attacher will be considered the
original file, and will be compared to the reloaded record. You can specify a
different original file:

```rb
original_file = attacher.file

attacher.set(new_file)

attacher.abstract_atomic_persist(original_file, **options)
```

If you want to execute some code before persistence, you can pass a block:

```rb
attacher.abstract_atomic_persist(**options) do
  # this will be executed before persistence
end
```

[atomic_helpers]: /lib/shrine/plugins/atomic_helpers.rb
