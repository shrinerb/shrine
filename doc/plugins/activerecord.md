# Active Record

The [`activerecord`][activerecord] plugin adds [Active Record] integration to
the attachment interface. It is built on top of the [`model`][model] plugin.

```rb
plugin :activerecord
```

## Attachment

When `Shrine::Attachment` module is included into an `ActiveRecord::Base`
subclass, additional [callbacks] are added to tie the attachment process to the
record lifecycle.

```rb
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment(:image) # adds callbacks & validations
end
```

### Callbacks

#### Save

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

#### Destroy

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

Active Record versions prior to 5.x silence errors that occur in callbacks,
which can make debugging more difficult, so it's recommended that you disable
this behaviour:

```rb
# This is the default in ActiveRecord 5
ActiveRecord::Base.raise_in_transactional_callbacks = true
```

Active Record also currently has a [bug with transaction callbacks], so if
you have any "after commit" callbacks, make sure to include Shrine's attachment
module *after* they have all been defined.

#### Skipping

If you don't want the attachment module to add any callbacks to your Active
Record model, you can set `:callbacks` to `false`:

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

#### Presence

If you want to validate presence of the attachment, you can use Active Record's
presence validator:

```rb
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment.new(:image)
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
  activerecord
    errors:
      models:
        photo:
          attributes:
            image:
              max_size: "must not be larger than %{max_size} bytes"
              not_image: "must be a common image format"
```

#### Skipping

If don't want the attachment module to merge file validations errors into
model errors, you can set `:validations` to `false`:

```rb
plugin :activerecord, validations: false
```

## Attacher

This section will cover methods added to the `Shrine::Attacher` instance. If
you're not familar with how to obtain it, see the [`model`][model] plugin docs.

### Atomic promotion

If you're promoting cached file to permanent storage
[asynchronously][backgrounding], you might want to handle the possibility of
the attachment changing during promotion. You can do that with
`Attacher#atomic_promote`:

```rb
# in your controller
attacher.attach_cached(io)
attacher.cached? #=> true
```
```rb
# in a background job
attacher.atomic_promote # promotes cached file and persists
attacher.stored? #=> true
```

After cached file is uploaded to permanent storage, the record is reloaded in
order to check whether the attachment hasn't changed, and if it hasn't the
attachment is persisted. If the attachment has changed,
`Shrine::AttachmentChanged` exception is raised.

Additional options are passed to `Attacher#promote`.

#### Reloader & persister

You can change how the record is reloaded or persisted during atomic promotion:

```rb
# reloader
attacher.atomic_promote(reload: :lock)       # uses database locking (default)
attacher.atomic_promote(reload: :fetch)      # reloads with no locking
attacher.atomic_promote(reload: ->(&b){...}) # custom reloader (see atomic_helpers plugin docs)
attacher.atomic_promote(reload: false)       # skips reloading

# persister
attacher.atomic_promote(persist: :save)   # persists stored file (default)
attacher.atomic_promote(persist: ->{...}) # custom persister (see atomic_helpers plugin docs)
attacher.atomic_promote(persist: false)   # skips persistence
```

For more details, see the [`atomic_helpers`][atomic_helpers] plugin docs.

### Atomic persistence

If you're updating something based on the attached file
[asynchronously][backgrounding], you might want to handle the possibility of
the attachment changing in the meanwhile. You can do that with
`Attacher#atomic_persist`:

```rb
# in a background job
attacher.refresh_metadata! # refresh_metadata plugin
attacher.atomic_persist # persists attachment data
```

The record is first reloaded in order to check whether the attachment hasn't
changed, and if it hasn't the attachment is persisted. If the attachment has
changed, `Shrine::AttachmentChanged` exception is raised.

#### Reloader & persister

You can change how the record is reloaded or persisted during atomic
persistence:

```rb
# reloader
attacher.atomic_persist(reload: :lock)    # uses database locking (default)
attacher.atomic_persist(reload: :fetch)   # reloads with no locking
attacher.atomic_persist(reload: ->(&b){}) # custom reloader (see atomic_helpers plugin docs)
attacher.atomic_persist(reload: false)    # skips reloading

# persister
attacher.atomic_persist(persist: :save) # persists stored file (default)
attacher.atomic_persist(persist: ->{})  # custom persister (see atomic_helpers plugin docs)
attacher.atomic_persist(persist: false) # skips persistence
```

For more details, see the [`atomic_helpers`][atomic_helpers] plugin docs.

### Persistence

You can call `Attacher#persist` to save any changes to the underlying record:

```rb
attacher.attach(io)
attacher.persist # saves the underlying record
```

### With other database plugins

If you have another database plugin loaded together with the `activerecord`
plugin, you can prefix any method above with `activerecord_*` to avoid naming
clashes:

```rb
attacher.activerecord_atomic_promote
attacher.activerecord_atomic_persist
attacher.activerecord_persist
```

[activerecord]: /lib/shrine/plugins/activerecord.rb
[Active Record]: https://guides.rubyonrails.org/active_record_basics.html
[model]: /doc/plugins/model.md#readme
[callbacks]: https://guides.rubyonrails.org/active_record_callbacks.html
[bug with transaction callbacks]: https://github.com/rails/rails/issues/14493
[validation]: /doc/plugins/validation.md#readme
[atomic_helpers]: /doc/plugins/atomic_helpers.md#readme
[backgrounding]: /doc/plugins/backgrounding.md#readme
