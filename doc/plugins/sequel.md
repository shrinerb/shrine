---
title: Sequel
---

The [`sequel`][sequel] plugin adds [Sequel] integration to the attachment
interface. It is built on top of the [`model`][model] plugin.

```rb
Shrine.plugin :sequel
```

## Attachment

Including a `Shrine::Attachment` module into a `Sequel::Model` subclass will:

* add [model] attachment methods
* add [validations](#validations) and [hooks](#hooks) to tie attachment process
  to the record lifecycle

```rb
class Photo < Sequel::Model # has `image_data` column
  include ImageUploader::Attachment(:image) # adds methods, callbacks & validations
end
```
```rb
photo = Photo.new

photo.image = file # cache attachment

photo.image      #=> #<Shrine::UploadedFile id="bc2e13.jpg" storage=:cache ...>
photo.image_data #=> '{"id":"bc2e13.jpg","storage":"cache","metadata":{...}}'

photo.save # persist, promote attachment, then persist again

photo.image      #=> #<Shrine::UploadedFile id="397eca.jpg" storage=:store ...>
photo.image_data #=> '{"id":"397eca.jpg","storage":"store","metadata":{...}}'

photo.destroy # delete attachment

photo.image.exists? #=> false
```

### Hooks

#### After Save

After a record is saved and the transaction is committed, `Attacher#finalize`
is called, which promotes cached file to permanent storage and deletes previous
file if any.

```rb
photo = Photo.new

photo.image = file
photo.image.storage_key #=> :cache

photo.save
photo.image.storage_key #=> :store
```

#### After Destroy

After a record is destroyed and the transaction is committed,
`Attacher#destroy_attached` method is called, which deletes stored attached
file if any.

```rb
photo = Photo.find(photo_id)
photo.image #=> #<Shrine::UploadedFile>
photo.image.exists? #=> true

photo.destroy
photo.image.exists? #=> false
```

#### Overriding hooks

You can override any of the following attacher methods to modify callback
behaviour:

* `Attacher#sequel_before_save`
* `Attacher#sequel_after_save`
* `Attacher#sequel_after_destroy`

```rb
class Shrine::Attacher
  def sequel_after_save
    super
    # ...
  end
end
```

#### Skipping Hooks

If you don't want the attachment module to add any hooks to your model, you can
set `:hooks` to `false`:

```rb
plugin :sequel, hooks: false
```

### Validations

If you're using the [`validation`][validation] plugin, the attachment module
will automatically merge attacher errors with model errors.

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 10 * 1024 * 1024
  end
end
```
```rb
photo = Photo.new
photo.image = file
photo.valid?
photo.errors #=> { image: ["size must not be greater than 10.0 MB"] }
```

#### Attachment Presence

If you want to validate presence of the attachment, you can use Sequel's
presence validator:

```rb
class Photo < Sequel::Model
  include ImageUploader::Attachment(:image)

  def validate
    super
    validates_presence :image
  end
end
```

#### Skipping Validations

If don't want the attachment module to merge file validations errors into
model errors, you can set `:validations` to `false`:

```rb
plugin :sequel, validations: false
```

## Attacher

You can also use `Shrine::Attacher` directly (with or without the
`Shrine::Attachment` module):

```rb
class Photo < Sequel::Model # has `image_data` column
end
```
```rb
photo    = Photo.new
attacher = ImageUploader::Attacher.from_model(photo, :image)

attacher.assign(file) # cache

attacher.file    #=> #<Shrine::UploadedFile id="bc2e13.jpg" storage=:cache ...>
photo.image_data #=> '{"id":"bc2e13.jpg","storage":"cache","metadata":{...}}'

photo.save        # persist
attacher.finalize # promote
photo.save        # persist

attacher.file    #=> #<Shrine::UploadedFile id="397eca.jpg" storage=:store ...>
photo.image_data #=> '{"id":"397eca.jpg","storage":"store","metadata":{...}}'
```

### Pesistence

The following persistence methods are added to `Shrine::Attacher`:

| Method                    | Description                                                            |
| :-----                    | :----------                                                            |
| `Attacher#atomic_promote` | calls `Attacher#promote` and persists if the attachment hasn't changed |
| `Attacher#atomic_persist` | saves changes if the attachment hasn't changed                         |
| `Attacher#persist`        | saves any changes to the underlying record                             |

See [persistence] docs for more details.

[sequel]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/sequel.rb
[Sequel]: https://sequel.jeremyevans.net/
[model]: https://shrinerb.com/docs/plugins/model
[validation]: https://shrinerb.com/docs/plugins/validation
[persistence]: https://shrinerb.com/docs/plugins/persistence
