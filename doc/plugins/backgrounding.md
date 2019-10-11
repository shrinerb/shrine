---
title: Backgrounding
---

The [`backgrounding`][backgrounding] plugin enables you to move promoting and
deleting of files into background jobs. This is especially useful if you're
processing [derivatives] and storing files to a remote storage service.

```rb
Shrine.plugin :backgrounding # load the plugin globally
```

The plugin provides `Attacher.promote_block` and `Attacher.destroy_block`
methods, which allow you to register blocks that will get executed in place of
synchronous promotion and deletion. Inside them you can spawn your background
jobs:

```rb
# register backgrounding blocks for all uploaders
Shrine::Attacher.promote_block do
  PromoteJob.perform_async(self.class.name, record.class.name, record.id, name, file_data)
end
Shrine::Attacher.destroy_block do
  DestroyJob.perform_async(self.class.name, data)
end
```
```rb
class PromoteJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    # attachment has changed or record has been deleted, nothing to do
  end
end
```
```rb
class DestroyJob
  include Sidekiq::Worker

  def perform(attacher_class, data)
    attacher_class = Object.const_get(attacher_class)

    attacher = attacher_class.from_data(data)
    attacher.destroy
  end
end
```

If you don't want to apply backgrounding for all uploaders, you can register
backgrounding blocks only for a specific uploader:

```rb
class MyUploader < Shrine
  # register backgrounding blocks only for this uploader
  Attacher.promote_block do
    PromoteJob.perform_async(self.class.name, record.class.name, record.id, name, file_data)
  end
  Attacher.destroy_block do
    DestroyJob.perform_async(self.class.name, data)
  end
end
```

Backgrounding will automatically get triggered as part of your attachment flow
if you're using `Shrine::Attachment` with a persistence plugin such as
`activerecord` or `sequel`:

```rb
photo = Photo.new
photo.image = file
photo.save    # spawns promote job
photo.destroy # spawns destroy job
```

In terms of `Shrine::Attacher`, the background jobs are spawned on
`Attacher#promote_cached` (called on `Attacher#finalize`) and
`Attacher#destroy_attached`:

```rb
attacher.assign(file)
attacher.finalize         # spawns promote job
attacher.destroy_attached # spawns destroy job
```

## Promotion

While background deletion acts only on file data, background promotion is more
complex as it deals with persistence and concurrency safety:

```rb
attacher = Shrine::Attacher.retrieve(model: record, name: name, file: file_data)
attacher.atomic_promote
```

The `Attacher.retrieve` and `Attacher#atomic_promote` methods are provided by
the [`atomic_helpers`][atomic_helpers] plugin, which is automatically loaded by
your persistence plugin (`activerecord`, `sequel`). They add concurrency safety
by verifying that the attachment hasn't changed on the outside before or after
promotion.

When we remove the concurrency safety, promotion would look like this:

```rb
attacher = record.send(:"#{name}_attacher")
attacher.promote
attacher.persist
```

## Backgrounding blocks

The blocks registered by `Attacher.promote_block` and `Attacher#destroy_block`
are by default evaluated in context of a `Shrine::Attacher` instance. You can
also use the explicit version by declaring an attacher argument:

```rb
Shrine::Attacher.promote_block do |attacher|
  PromoteJob.perform_async(
    attacher.class.name,
    attacher.record.class.name,
    attacher.record.id,
    attacher.name,
    attacher.file_data,
  )
end

Shrine::Attacher.destroy_block do |attacher|
  DestroyJob.perform_async(
    attacher.class.name,
    attacher.data,
  )
end
```

You can also register backgrounding blocks on attacher *instances* for more
flexibility:

```rb
photo.image_attacher.promote_block do |attacher|
  PromoteJob.perform_async(
    attacher.class.name,
    attacher.record.class.name,
    attacher.record.id,
    attacher.name,
    attacher.file_data,
    current_user.id, # pass arguments known at the controller level
  )
end

photo.image = file
photo.save # executes the promote block above
```

[backgrounding]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/backgrounding.rb
[derivatives]: https://shrinerb.com/docs/plugins/derivatives
[atomic_helpers]: https://shrinerb.com/docs/plugins/atomic_helpers
