---
id: upgrading-to-3
title: Upgrading to Shrine 3.x
---

This guide provides instructions for upgrading Shrine in your apps to version
3.x. If you're looking for a full list of changes, see the **[3.0 release
notes]**.

If you would like assistance with the upgrade, I'm available for consultation,
you can email me at <janko.marohnic@gmail.com>.

## Attacher

The `Shrine::Attacher` class has been rewritten in Shrine 3.0, though much of
the main API remained the same.

### Model

The main change is that `Attacher.new` is now used for initializing the
attacher without a model:

```rb
attacher = Shrine::Attacher.new
#=> #<Shrine::Attacher>

attacher = Shrine::Attacher.new(photo, :image)
# ~> ArgumentError: invalid number of arguments
```

To initialize an attacher with a model, use `Attacher.from_model` provided by
the new [`model`][model] plugin (which is automatically loaded by
`activerecord` and `sequel` plugins):

```rb
attacher = Shrine::Attacher.from_model(photo, :image)
# ...
```

If you're using the `Shrine::Attachment` module with POROs, make sure to load
the `model` plugin.

```rb
Shrine.plugin :model
```
```rb
class Photo < Struct.new(:image_data)
  include Shrine::Attachment(:image)
end
```

### Data attribute

The `Attacher#read` method has been removed. If you want to generate serialized
attachment data, use `Attacher#column_data`. Otherwise if you want to generate
hash attachment data, use `Attacher#data`.

```rb
attacher.column_data #=> '{"id":"...","storage":"...","metadata":{...}}'
attacher.data        #=> { "id" => "...", "storage" => "...", "metadata" => { ... } }
```

The `Attacher#data_attribute` has been renamed to `Attacher#attribute`.

### State

The attacher now maintains its own state, so if you've previously modified the
`#<name>_data` record attribute and expected the changes to be picked up by the
attacher, you'll now need to call `Attacher#reload` for that:

```rb
attacher.file #=> nil
record.image_data = '{"id":"...","storage":"...","metadata":{...}}'
attacher.file #=> nil
attacher.reload
attacher.file #=> #<Shrine::UploadedFile ...>
```

### Assigning

The `Attacher#assign` method now raises an exception when non-cached uploaded
file data is assigned:

```rb
# Shrine 2.x
attacher.assign('{"id": "...", "storage": "store", "metadata": {...}}') # ignored

# Shrine 3.0
attacher.assign('{"id": "...", "storage": "store", "metadata": {...}}')
#~> Shrine::Error: expected cached file, got #<Shrine::UploadedFile storage=:store ...>
```

### Validation

The validation functionality has been extracted into the `validation` plugin.
If you're using the `validation_helpers` plugin, it will automatically load
`validation` for you. Otherwise you'll have to load it explicitly:

```rb
Shrine.plugin :validation
```
```rb
class MyUploader < Shrine
  Attacher.validate do
    # ...
  end
end
```

### Setting

The `Attacher#set` method has been renamed to `Attacher#change`, and the
private `Attacher#_set` method has been renamed to `Attacher#set` and made
public:

```rb
attacher.change(uploaded_file) # sets file, remembers previous file, runs validations
attacher.set(uploaded_file)    # sets file
```

If you've previously used `Attacher#replace` directly to delete previous file,
it has now been renamed to `Attacher#destroy_previous`.

Also note that `Attacher#attached?` now returns whether a file is attached,
while `Attacher#changed?` continues to return whether the attachment has
changed.

### Uploading and deleting

The `Attacher#store!` and `Attacher#cache!` methods have been removed, you
should now use `Attacher#upload` instead:

```rb
attacher.upload(io)               # uploads to permanent storage
attacher.upload(io, :cache)       # uploads to temporary storage
attacher.upload(io, :other_store) # uploads to another storage
```

The `Attacher#delete!` method has been removed as well, you should instead just
delete the file directly via `UploadedFile#delete`.

### Promoting

If you were promoting manually, the `Attacher#promote` method will now only
save promoted file in memory, it won't persist the changes.

```rb
attacher.promote
# ...
record.save # you need to persist the changes
```

If you want the concurrenct-safe promotion with persistence, use the new
`Attacher#atomic_promote` method.

```rb
attacher.atomic_promote
```

The `Attacher#swap` method has been removed. If you were using it directly, you
can use `Attacher#set` and `Attacher#atomic_persist` instead:

```rb
current_file = attacher.file
attacher.set(new_file)
attacher.atomic_persist(current_file)
```

## Backgrounding

The `backgrounding` plugin has been rewritten in Shrine 3.0 and has a new API.

```rb
Shrine.plugin :backgrounding
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

### Dual support

When you're making the switch in production, there might still be jobs in the
queue that have the old argument format. So, we'll initially want to handle
both argument formats, and then switch to the new one once the jobs with old
format have been drained.

```rb
class PromoteJob
  include Sidekiq::Worker

  def perform(*args)
    if args.one?
      file_data, (record_class, record_id), name, shrine_class =
        args.first.values_at("attachment", "record", "name", "shrine_class")

      record         = Object.const_get(record_class).find(record_id) # if using Active Record
      attacher_class = Object.const_get(shrine_class)::Attacher
    else
      attacher_class, record_class, record_id, name, file_data = args

      attacher_class = Object.const_get(attacher_class)
      record         = Object.const_get(record_class).find(record_id) # if using Active Record
    end

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    # attachment has changed or record has been deleted, nothing to do
  end
and
```
```rb
class DestroyJob
  include Sidekiq::Worker

  def perform(*args)
    if args.one?
      data, shrine_class = args.first.values_at("attachment", "shrine_class")

      data           = JSON.parse(data)
      attacher_class = Object.const_get(shrine_class)::Attacher
    else
      attacher_class, data = args

      attacher_class = Object.const_get(attacher_class)
    end

    attacher = attacher_class.from_data(data)
    attacher.destroy
  end
and
```

### Attacher backgrounding

In Shrine 2.x, `Attacher#_promote` and `Attacher#_delete` methods could be used
to spawn promote and delete jobs. This is now done by `Attacher#promote_cached`
and `Attacher#destroy_attached`:

```rb
attacher.promote_cached   # will spawn background job if registered
attacher.destroy_attached # will spawn background job if registered
```

If you want to explicitly call backgrounding blocks, you can use
`Attacher#promote_background` and `Attacher#destroy_background`:

```rb
attacher.promote_background # calls promote block
attacher.destroy_background # calls destroy block
```

## Versions

The `versions`, `processing`, `recache`, and `delete_raw` plugins have been
deprecated in favour of the new **[`derivatives`][derivatives]** plugin.

Let's assume you have the following `versions` configuration:

```rb
class ImageUploader < Shrine
  plugin :processing
  plugin :versions
  plugin :delete_raw

  process(:store) do |file, context|
    versions = { original: file }

    file.download do |original|
      magick = ImageProcessing::MiniMagick.source(original)

      versions[:large]  = magick.resize_to_limit!(800, 800)
      versions[:medium] = magick.resize_to_limit!(500, 500)
      versions[:small]  = magick.resize_to_limit!(300, 300)
    end

    versions
  end
end
```

When an attached file is promoted to permanent storage, the versions would
automatically get generated:

```rb
photo = Photo.new(photo_params)

if photo.valid?
  photo.save # generates versions on promotion
  # ...
else
  # ...
end
```

With `derivatives`, the original file is automatically downloaded and retained
during processing, so the setup is simpler:

```rb
Shrine.plugin :derivatives,
  create_on_promote:      true, # automatically create derivatives on promotion
  versions_compatibility: true  # handle versions column format
```
```rb
class ImageUploader < Shrine
  Attacher.derivatives do |original|
    magick = ImageProcessing::MiniMagick.source(original)

    # the :original file should NOT be included anymore
    {
      large:  magick.resize_to_limit!(800, 800),
      medium: magick.resize_to_limit!(500, 500),
      small:  magick.resize_to_limit!(300, 300),
    }
  end
end
```
```rb
photo = Photo.new(photo_params)

if photo.valid?
  photo.save # creates derivatives on promotion
  # ...
else
  # ...
end
```

### Accessing derivatives

The derivative URLs are accessed in the same way as versions:

```rb
photo.image_url(:small)
```

But the files themselves are accessed differently:

```rb
# versions
photo.image #=>
# {
#   original: #<Shrine::UploadedFile ...>,
#   large: #<Shrine::UploadedFile ...>,
#   medium: #<Shrine::UploadedFile ...>,
#   small: #<Shrine::UploadedFile ...>,
# }
photo.image[:medium] #=> #<Shrine::UploadedFile ...>
```
```rb
# derivatives
photo.image_derivatives #=>
# {
#   large: #<Shrine::UploadedFile ...>,
#   medium: #<Shrine::UploadedFile ...>,
#   small: #<Shrine::UploadedFile ...>,
# }
photo.image(:medium) #=> #<Shrine::UploadedFile ...>
```

### Migrating versions

The `versions` and `derivatives` plugins save processed file data to the
database column in different formats:

```rb
# versions
{
  "original": { "id": "...", "storage": "...", "metadata": { ... } },
  "large":    { "id": "...", "storage": "...", "metadata": { ... } },
  "medium":   { "id": "...", "storage": "...", "metadata": { ... } },
  "small":    { "id": "...", "storage": "...", "metadata": { ... } }
}
```
```rb
# derivatives
{
  "id": "...",
  "storage": "...",
  "metadata": { ... },
  "derivatives": {
    "large":  { "id": "...", "storage": "...", "metadata": { ... } },
    "medium": { "id": "...", "storage": "...", "metadata": { ... } },
    "small":  { "id": "...", "storage": "...", "metadata": { ... } }
  }
}
```

The `:versions_compatibility` flag to the `derivatives` plugin enables it to
read the `versions` format, which aids in transition. Once the `derivatives`
plugin has been deployed to production, you can update existing records with
the new column format:

```rb
Photo.find_each do |photo|
  photo.image_attacher.write
  photo.image_attacher.atomic_persist
end
```

Afterwards you should be able to remove the `:versions_compatibility` flag.

### Backgrounding derivatives

If you're using the `backgrounding` plugin, you can trigger derivatives
creation in the `PromoteJob` instead of the controller:

```rb
class PromoteJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record.id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.create_derivatives # call derivatives processor
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    # attachment has changed or record has beeen deleted, nothing to do
  end
end
```

#### Recache

If you were using the `recache` plugin, you can replicate the behaviour by
creating another derivatives processor that you will trigger in the controller:

```rb
class ImageUploader < Shrine
  Attacher.derivatives do |original|
    # this will be triggered in the background job
  end

  Attacher.derivatives :foreground do |original|
    # this will be triggered in the controller
  end
end
```
```rb
photo = Photo.new(photo_params)

if photo.valid?
  photo.image_derivatives!(:foreground) if photo.image_changed?
  photo.save
  # ...
else
  # ...
end
```

### Default URL

If you were using the `default_url` plugin, the `Attacher.default_url` now
receives a `:derivative` option:

```rb
Attacher.default_url do |derivative: nil, **|
  "https://my-app.com/fallbacks/#{derivative}.jpg" if derivative
end
```

#### Fallback to original

With the `versions` plugin, a missing version URL would automatically fall back
to the original file. The `derivatives` plugin has no such fallback, but you
can configure it manually:

```rb
Attacher.default_url do |derivative: nil, **|
  file&.url if derivative
end
```

#### Fallback to version

The `versions` plugin had the ability to fall back missing version URL to
another version that already exists. The `derivatives` plugin doesn't have this
built in, but you can implement it as follows:

```rb
DERIVATIVE_FALLBACKS = { foo: :bar, ... }

Attacher.default_url do |derivative: nil, **|
  derivatives[DERIVATIVE_FALLBACKS[derivative]]&.url if derivative
end
```

### Location

The `Shrine#generate_location` method will now receive a `:derivative`
parameter instead of `:version`:

```rb
class MyUploader < Shrine
  def generate_location(io, derivative: nil, **)
    derivative #=> :large, :medium, :small, ...
    # ...
  end
end
```

### Overwriting original

With the `derivatives` plugin, saving processed files separately from the
original file, so the original file is automatically kept. This means it's not
possible anymore to overwrite the original file as part of processing.

However, **it's highly recommended to always keep the original file**, even if
you don't plan to use it. That way, if there is ever a need to reprocess
derivatives, you have the original file to use as a base.

That being said, if you still want to overwrite the original file, [this
thread][overwriting original] has some tips.

## Other

### Processing

The `processing` plugin has been deprecated over the new
[`derivatives`][derivatives] plugin. If you were previously replacing the
original file:

```rb
class MyUploader < Shrine
  plugin :processing

  process(:store) do |io, context|
    ImageProcessing::MiniMagick
      .source(io.download)
      .resize_to_limit!(1600, 1600)
  end
end
```

you should now add the processed file as a derivative:

```rb
class MyUploader < Shrine
  plugin :derivatives

  Attacher.derivatives do |original|
    magick = ImageProcessing::MiniMagick.source(original)

    { normalized: magick.resize_to_limit!(1600, 1600) }
  end
end
```

### Parallelize

The `parallelize` plugin has been removed. With `derivatives` plugin you can
parallelize uploading processed files manually:

```rb
# Gemfile
gem "concurrent-ruby"
```
```rb
require "concurrent"

attacher    = photo.image_attacher
derivatives = attacher.process_derivatives

tasks = derivatives.map do |name, file|
  Concurrent::Promises.future(name, file) do |name, file|
    attacher.add_derivative(name, file)
  end
end

Concurrent::Promises.zip(*tasks).wait!
```

### Logging

The `logging` plugin has been removed in favour of the
[`instrumentation`][instrumentation] plugin. You can replace code like

```rb
Shrine.plugin :logging, logger: Rails.logger
```

with

```rb
Shrine.logger = Rails.logger

Shrine.plugin :instrumentation
```

### Backup

The `backup` plugin has been removed in favour of the new
[`mirroring`][mirroring] plugin. You can replace code like

```rb
Shrine.plugin :backup, storage: :backup_store
```

with

```rb
Shrine.plugin :mirroring, mirror: { store: :backup_store }
```

### Copy

The `copy` plugin has been removed as its behaviour can now be achieved easily.
You can replace code like

```rb
Shrine.plugin :copy
```
```rb
attacher.copy(other_attacher)
```

with

```rb
attacher.attach other_attacher.file
attacher.add_derivatives other_attacher.derivatives # if using derivatives
```

### Moving

The `moving` plugin has been removed in favour of the `:move` option for
`FileSystem#upload`. You can set this option as default using the
`upload_options` plugin (the example assumes both `:cache` and `:store` are
FileSystem storages):

```rb
Shrine.plugin :upload_options, cache: { move: true }, store: { move: true }
```

### Parsed JSON

The `parsed_json` plugin has been removed as it's now the default behaviour.

```rb
# this now works by default
photo.image = { "id" => "d7e54d6ef2.jpg", "storage" => "cache", "metadata" => { ... } }
```

### Module Include

The `module_include` plugin has been deprecated over overriding core classes
directly. You can replace code like

```rb
class MyUploader < Shrine
  plugin :module_include

  file_methods do
    def image?
      mime_type.start_with?("image")
    end
  end
end
```

with

```rb
class MyUploader < Shrine
  class UploadedFile
    def image?
      mime_type.start_with?("image")
    end
  end
end
```

[3.0 release notes]: https://shrinerb.com/docs/release_notes/3.0.0
[model]: https://shrinerb.com/docs/plugins/model
[derivatives]: https://shrinerb.com/docs/plugins/derivatives
[instrumentation]: https://shrinerb.com/docs/plugins/instrumentation
[mirroring]: https://shrinerb.com/docs/plugins/mirroring
[overwriting original]: https://discourse.shrinerb.com/t/keep-original-file-after-processing/50/4
