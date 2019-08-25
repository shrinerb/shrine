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

#### Skipping Callbacks

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

#### Attachment Presence

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

#### Skipping Validations

If don't want the attachment module to merge file validations errors into
model errors, you can set `:validations` to `false`:

```rb
plugin :sequel, validations: false
```

## Attacher

This section will cover methods added to the `Shrine::Attacher` instance. If
you're not familar with how to obtain it, see the [`model`][model] plugin docs.

The following persistence methods are added to the attacher:

| Method                    | Description                                                            |
| :-----                    | :----------                                                            |
| `Attacher#atomic_promote` | calls `Attacher#promote` and persists if the attachment hasn't changed |
| `Attacher#atomic_persist` | saves changes if the attachment hasn't changed                         |
| `Attacher#persist`        | saves any changes to the underlying record                             |

See [persistence] docs for more details.

[sequel]: /lib/shrine/plugins/sequel.rb
[Sequel]: https://sequel.jeremyevans.net/
[model]: /doc/plugins/model.md#readme
[hooks]: http://sequel.jeremyevans.net/rdoc/files/doc/model_hooks_rdoc.html
[validation]: /doc/plugins/validation.md#readme
[persistence]: /doc/plugins/persistence.md#readme
