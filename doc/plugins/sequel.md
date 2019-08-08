# Sequel

The [`sequel`][sequel] plugin adds [Sequel] integration to the attachment
interface. It is built on top of the [`model`][model] plugin.

```rb
plugin :sequel
```

## Attachment

When `Shrine::Attachment` module is included into a `Sequel::Model` subclass,
additional [hooks] are added to tie the attachment process to the record
lifecycle.

```rb
class Photo < Sequel::Model
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

#### Skipping

If you don't want the attachment module to add any callbacks to your Sequel
model, you can set `:callbacks` to `false`:

```rb
plugin :sequel, callbacks: false
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

If you want to validate presence of the attachment, you can use Sequel's
presence validator:

```rb
class Photo < Sequel::Model
  include ImageUploader::Attachment.new(:image)

  plugin :validation_helpers

  def validate
    super
    validates_presence :image
  end
end
```

#### Skipping

If don't want the attachment module to merge file validations errors into
model errors, you can set `:validations` to `false`:

```rb
plugin :sequel, validations: false
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
attacher.atomic_promote(reload: :lock)    # uses database locking (default)
attacher.atomic_promote(reload: :fetch)   # reloads with no locking
attacher.atomic_promote(reload: ->(&b){}) # custom reloader (see atomic_helpers plugin docs)
attacher.atomic_promote(reload: false)    # skips reloading

# persister
attacher.atomic_promote(persist: :save) # persists stored file (default)
attacher.atomic_promote(persist: ->{})  # custom persister (see atomic_helpers plugin docs)
attacher.atomic_promote(persist: false) # skips persistence
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
attacher.atomic_persist(reload: :lock)       # uses database locking (default)
attacher.atomic_persist(reload: :fetch)      # reloads with no locking
attacher.atomic_persist(reload: ->(&b){...}) # custom reloader (see atomic_helpers plugin docs)
attacher.atomic_persist(reload: false)       # skips reloading

# persister
attacher.atomic_persist(persist: :save)   # persists stored file (default)
attacher.atomic_persist(persist: ->{...}) # custom persister (see atomic_helpers plugin docs)
attacher.atomic_persist(persist: false)   # skips persistence
```

For more details, see the [`atomic_helpers`][atomic_helpers] plugin docs.

### Persistence

You can call `Attacher#persist` to save any changes to the underlying record:

```rb
attacher.attach(io)
attacher.persist # saves the underlying record
```

### With other database plugins

If you have another database plugin loaded together with the `sequel` plugin,
you can prefix any method above with `sequel_*` to avoid naming clashes:

```rb
attacher.sequel_atomic_promote
attacher.sequel_atomic_persist
attacher.sequel_persist
```

[sequel]: /lib/shrine/plugins/sequel.rb
[Sequel]: https://sequel.jeremyevans.net/
[model]: /doc/plugins/model.md#readme
[hooks]: http://sequel.jeremyevans.net/rdoc/files/doc/model_hooks_rdoc.html
[validation]: /doc/plugins/validation.md#readme
[atomic_helpers]: /doc/plugins/atomic_helpers.md#readme
[backgrounding]: /doc/plugins/backgrounding.md#readme
