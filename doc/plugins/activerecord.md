---
title: Active Record
---

The [`activerecord`][activerecord] plugin adds [Active Record] integration to
the attachment interface. It is built on top of the [`model`][model] plugin.

```rb
Shrine.plugin :activerecord
```

## Attachment

Including a `Shrine::Attachment` module into an `ActiveRecord::Base` subclass
will:

* add [model] attachment methods
* add [validations](#validations) and [callbacks](#callbacks) to tie attachment
  process to the record lifecycle

```rb
class Photo < ActiveRecord::Base # has `image_data` column
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

### Callbacks

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

#### Caveats

Active Record currently has a [bug with transaction callbacks], so if you have
any "after commit" callbacks, make sure to include Shrine's attachment module
*after* they have all been defined.

#### Duplicating records

Since a record being created can't yet have a confirmed attachment of its own
to safely replace, Shrine never deletes the previous file when the attachment
changes as part of *creating* a record, only when *updating* one. This
matters most when duplicating a record: `#dup` performs a shallow copy, so a
duplicated record initially points to the *same* underlying file as the
original (they'll have the same attached file data), and replacing the
attachment on the duplicate before it's ever saved won't affect the original:

```rb
photo  = Photo.create(image: file)
photo2 = photo.dup

photo2.update!(image: new_file) # replaces the attachment on `photo2`
photo.image.exists? #=> true (not affected)
```

Once `photo2` has been saved, replacing its attachment again behaves
normally (the previously attached file is deleted):

```rb
previous_image = photo2.image
photo2.update!(image: another_file)
previous_image.exists? #=> false
```

Keep in mind this only protects against *replacing* the attachment on create.
As long as `photo` and `photo2` continue to reference the same underlying
file (i.e. `photo2` is saved without ever changing its attachment), destroying
either record will still delete the file the other one references, since
Shrine has no way of knowing the file is shared:

```rb
photo2.save! # still references the same file as `photo`

photo2.destroy
photo.image.exists? #=> false
```

If you want the duplicated record to have its own independent copy of the
file from the start, so that destroying either record is also safe, upload a
new copy explicitly after duplicating:

```rb
photo  = Photo.create(image: file)
photo2 = photo.dup

photo2.image_attacher.set(nil)
photo2.image_attacher.attach(photo.image, storage: photo.image.storage_key)
photo2.save!

photo2.destroy # no longer affects `photo`
photo.image.exists? #=> true
```

#### Overriding callbacks

You can override any of the following attacher methods to modify callback
behaviour:

* `Attacher#activerecord_before_save`
* `Attacher#activerecord_after_save`
* `Attacher#activerecord_after_destroy`

```rb
class Shrine::Attacher
  def activerecord_after_save
    super
    # ...
  end
end
```

#### Skipping Callbacks

If you don't want the attachment module to add any callbacks to your model, you
can set `:callbacks` to `false`:

```rb
plugin :activerecord, callbacks: false
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

If you want to validate presence of the attachment, you can use Active Record's
presence validator:

```rb
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment(:image)

  validates_presence_of :image
end
```

#### I18n

If you want Active Record to translate attacher error messages, you can use
symbols or arrays of symbols and options for validation errors:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 10 * 1024 * 1024, message: -> (max) { [:too_large, max: max] }
    validate_mime_type %w[image/jpeg image/png], message: :not_image
  end
end
```
```yml
en:
  activerecord:
    errors:
      models:
        photo:
          attributes:
            image:
              max_size: "must not be larger than %{max_size} bytes"
              not_image: "must be a common image format"
```

#### Skipping Validations

If don't want the attachment module to merge file validations errors into
model errors, you can set `:validations` to `false`:

```rb
plugin :activerecord, validations: false
```

### JSON columns

When the data attribute is backed by a `json` or `jsonb` database column,
Active Record already serializes hashes into JSON, so Shrine skips its own
serialization to avoid double encoding.

```rb
class Photo < ActiveRecord::Base # `image_data` is a jsonb column
  include ImageUploader::Attachment(:image)
end
```
```rb
photo.image = file
photo.image_data #=> { "id" => "bc2e13.jpg", "storage" => "cache", "metadata" => { ... } }
```

By default this detection only looks at real database columns. If you declare
the data attribute type via the [Attributes API] (e.g. on top of a `text`
column), enable the `:attribute_types` option so it's recognized as well:

```rb
plugin :activerecord, attribute_types: true
```
```rb
class Photo < ActiveRecord::Base # `image_data` is a text column
  include ImageUploader::Attachment(:image)

  attribute :image_data, :json
end
```

This option defaults to `false` for backwards compatibility.

## Attacher

You can also use `Shrine::Attacher` directly (with or without the
`Shrine::Attachment` module):

```rb
class Photo < ActiveRecord::Base # has `image_data` column
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

### Persistence

The following persistence methods are added to `Shrine::Attacher`:

| Method                    | Description                                                            |
| :-----                    | :----------                                                            |
| `Attacher#atomic_promote` | calls `Attacher#promote` and persists if the attachment hasn't changed |
| `Attacher#atomic_persist` | saves changes if the attachment hasn't changed                         |
| `Attacher#persist`        | saves any changes to the underlying record                             |

See [persistence] docs for more details.

[activerecord]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/activerecord.rb
[Active Record]: https://guides.rubyonrails.org/active_record_basics.html
[Attributes API]: https://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html#method-i-attribute
[model]: https://shrinerb.com/docs/plugins/model
[callbacks]: https://guides.rubyonrails.org/active_record_callbacks.html
[bug with transaction callbacks]: https://github.com/rails/rails/issues/14493
[validation]: https://shrinerb.com/docs/plugins/validation
[persistence]: https://shrinerb.com/docs/plugins/persistence
[Replacing]: https://shrinerb.com/docs/attacher#replacing
