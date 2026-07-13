---
title: Backgrounding
---

The [`backgrounding`][backgrounding] plugin enables you to move promoting and
deleting of files into background jobs. This is especially useful if you're
processing [derivatives] and storing files to a remote storage service.

```rb
Shrine.plugin :backgrounding # load the plugin globally
```

## Setup

Define background jobs that will promote and destroy attachments:

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

Then, in your initializer, you can configure all uploaders to use these jobs:

```rb
Shrine::Attacher.promote_block do
  PromoteJob.perform_async(self.class.name, record.class.name, record.id, name.to_s, file_data)
end
Shrine::Attacher.destroy_block do
  DestroyJob.perform_async(self.class.name, data)
end
```

Alternatively, you can setup backgrounding only for specific uploaders:

```rb
class MyUploader < Shrine
  Attacher.promote_block do
    PromoteJob.perform_async(self.class.name, record.class.name, record.id, name.to_s, file_data)
  end
  Attacher.destroy_block do
    DestroyJob.perform_async(self.class.name, data)
  end
end
```

## How it works

If backgrounding blocks are registered, they will be automatically called on
`Attacher#promote_cached` and `Attacher#destroy_previous` (called by
`Attacher#finalize`), and `Attacher#destroy_attached`.

```rb
attacher.assign(file)
attacher.finalize         # spawns promote job
attacher.destroy_attached # spawns destroy job
```

These methods are automatically called as part of the attachment flow if you're
using `Shrine::Attachment` with a persistence plugin such as `activerecord` or
`sequel`.

```rb
photo = Photo.new
photo.image = file
photo.save    # spawns promote job
photo.destroy # spawns destroy job
```

### Atomic promotion

Inside the promote job, we use `Attacher.retrieve` and
`Attacher#atomic_promote` for concurrency safety. These methods are provided
by the [`atomic_helpers`][atomic_helpers] plugin, which is loaded automatically
by your persistence plugin (`activerecord`, `sequel`).

```rb
attacher = Shrine::Attacher.retrieve(model: record, name: name, file: file_data)
attacher.atomic_promote
```

Without concurrency safety, promotion would look like this:

```rb
attacher = record.send(:"#{name}_attacher")
attacher.promote
attacher.persist
```

## Registering backgrounding blocks

The blocks registered by `Attacher.promote_block` and `Attacher#destroy_block`
are by default evaluated in context of a `Shrine::Attacher` instance. You can
also use the explicit version by declaring an attacher argument:

```rb
Shrine::Attacher.promote_block do |attacher|
  PromoteJob.perform_async(
    attacher.class.name,
    attacher.record.class.name,
    attacher.record.id,
    attacher.name.to_s,
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
    attacher.name.to_s,
    attacher.file_data,
    current_user.id, # pass arguments known at the controller level
  )
end

photo.image = file
photo.save # executes the promote block above
```

## Calling backgrounding blocks

If you want to call backgrounding blocks directly, you can do that by calling
`Attacher#promote_background` and `Attacher#destroy_background`.

```rb
attacher.promote_background # calls promote block directly
attacher.destroy_background # calls destroy block directly
```

Any options passed to these methods will be forwarded to the background block:

```rb
attacher.promote_background(foo: "bar")
```
```rb
# with instance eval
Shrine::Attacher.promote_block do |**options|
  options #=> { foo: "bar" }
end

# without instance eval
Shrine::Attacher.promote_block do |attacher, **options|
  options #=> { foo: "bar" }
end
```

## Disabling backgrounding

If you've registered backgrounding blocks, but want to temporarily disable them
and make the execution synchronous, you can override them on the attacher level
and call the default behaviour:

```rb
photo.image_attacher.promote_block { promote } # promote synchronously
photo.image_attacher.destroy_block { destroy } # destroy synchronously

# ... now promotion and deletion will be synchronous ...
```

You can also do this on the class level if you want to disable backgrounding
that was set up by a superclass:

```rb
class MyUploader < Shrine
  Attacher.promote_block { promote } # promote synchronously
  Attacher.destroy_block { destroy } # destroy synchronously
end
```

## Testing

Since promotion happens in a background job, it won't have run yet
immediately after you save the record, so asserting on the promoted file's
data or location will fail unless the job has actually been executed. For
example, with Active Job you'll need to run enqueued jobs inline:

```rb
require "active_job/test_helper"

include ActiveJob::TestHelper

perform_enqueued_jobs do
  photo = Photo.create(image: file) # spawns promote job
end

photo.reload # fetch attachment data updated by the background job
photo.image.storage_key #=> :store
```

Keep in mind that while the file is cached (i.e. before the promote job has
run), the record may not have an `id` yet, so plugins like [`pretty_location`]
that build the storage location from the record's identifier won't be able
to include it until promotion happens.

[backgrounding]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/backgrounding.rb
[`pretty_location`]: https://shrinerb.com/docs/plugins/pretty_location
[derivatives]: https://shrinerb.com/docs/plugins/derivatives
[atomic_helpers]: https://shrinerb.com/docs/plugins/atomic_helpers
