---
title: Atomic Helpers
---

The [`atomic_helpers`][atomic_helpers] plugin provides API for retrieving and
persisting attachments in a concurrency-safe way, which is especially useful
when using the `backgrounding` plugin. The database plugins (`activerecord`
and `sequel`) implement atomic promotion and atomic persistence on top of this
plugin.

```rb
plugin :atomic_helpers
```

## Problem Statement

What happens if two different processors (web workers, background jobs,
command-line executions, whatever) try to edit a shrine attachment
concurrently? The kinds of edits typically made include: "promoting a file",
moving it to a different storage and persisting that change in the model;
adding or changing a derivative; adding or changing a metadata element.

There are two main categories of "race condition":

1. The file could be switched out from under you. If you were promoting a file,
but some other process has *changed* the attachment, you don't want to
overwrite it with the promomoted version of the *prior* attacchment. Likewise,
if you were adding metadata or a derivative, they would be corresponding to a
certain attachment, and you don't want to accidentally add them to a now changed
attacchment for which they are inappropriate.

2. Overwriting each other's edits. Since all shrine (meta)data is stored in a
single JSON hash, standard implementations will write the entire JSON hash at
once to a rdbms column or other store. If two processes both read in the hash,
make a change to different keys in it, and then write it back out, the second
process to write will 'win' and overwrite changes made by the first.

The atomic helpers give you tools to avoid both of these sorts of race
conditions, under conditions of concurrent editing.

## High-level ORM helpers

If you are using the `sequel` or `activerecord` plugins, they give you two
higher-level helpers: `atomic_persist` and `atomic_promote`. See the
[persistence]  documentation for more.


## Retrieving

The `Attacher.retrieve` method provided by the plugin instantiates an attacher
from a record instance, attachment name and attachment data, asserting that the
given attachment data matches the attached file on the record.

```rb
# with a model instance
Shrine::Attacher.retrieve(
  model: photo,
  name:  :image,
  file:  { "id" => "abc123", "storage" => "cache" },
)
#=> #<Shrine::Attacher ...>

# with an entity instance
Shrine::Attacher.retrieve(
  entity: photo,
  name:   :image,
  file:   { "id" => "abc123", "storage" => "cache" },
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
Shrine::Attacher.retrieve(model: photo, name: :image, file: { ... })
#=> #<ImageUploader::Attacher ...>
```

Otherwise it will call `Attacher.from_model`/`Attacher.from_entity` from the
`model`/`entity` plugin, in which case you need to make sure to call
`Attacher.retrieve` on the appropriate attacher class.

```rb
ImageUploader::Attacher.retrieve(entity: photo, name: :image, file: { ... })
#=> #<ImageUploader::Attacher ...>
```

If the attached file on the record doesn't match the provided attachment data,
a `Shrine::AttachmentChanged` exception is raised. Note that metadata is
allowed to differ, Shrine will only compare location and storage of the file.

```rb
photo.image_data #=> '{"id":"foo","storage":"store","metadata":{...}}'

Shrine::Attacher.retrieve(
  model: photo,
  name: :image,
  file: { "id" => "bar", "storage" => "store" },
)
# ~> Shrine::AttachmentChanged: attachment has changed
```

### File data

The `Attacher#file_data` method can be used for sending the attached file data
into a background job. It returns only location and storage of the attached
file, leaving out any metadata or derivatives data that `Attacher#data` would
return. This way the background job payload is kept light.

```rb
attacher.file_data #=> { "id" => "abc123", "storage" => "store" }
```

This value can then be passed as the `:file` argument to
`Shrine::Attacher.retrieve`.

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
```
```rb
# in a background job
attacher.abstract_atomic_promote(reload: -> (&block) { ... }, persist: -> { ... })
attacher.stored? #=> true
```

If the attachment has changed during promotion, the promoted file is deleted and
a `Shrine::AttachmentChanged` exception is raised.

If you want to execute some code after the attachment change check but before
persistence, you can pass a block:

```rb
attacher.abstract_atomic_promote(**options) do |reloaded_attacher|
  # this will be executed before persistence
end
```

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

If you want to execute some code after the attachment change check but before
persistence, you can pass a block:

```rb
attacher.abstract_atomic_persist(**options) do |reloaded_attacher|
  # this will be executed before persistence
end
```

[atomic_helpers]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/atomic_helpers.rb

[persistence]: https://shrinerb.com/docs/plugins/persistence

[backgrounding]: https://shrinerb.com/docs/plugins/backgrounding
