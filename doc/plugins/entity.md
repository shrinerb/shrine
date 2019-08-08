# Entity

The [`entity`][entity] plugin provides integration for handling attachments on
immutable structs. It is built on top of the [`column`][column] plugin.

```rb
plugin :entity
```

## Attachment

Including a `Shrine::Attachment` module into an entity class will add the
following instance methods:

* `#<name>` – returns the attached file
* `#<name>_url` – returns the attached file URL
* `#<name>_attacher` – returns a `Shrine::Attacher` instance

These methods assume the entity has a `#<name>_data` attribute and read
attachment data from it.

```rb
class Photo
  include ImageUploader::Attachment(:file)
end
```
```rb
photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')
photo.image          #=> #<ImageUploader::UploadedFile>
photo.image_url      #=> "https://example.com/image.jpg"
photo.image_attacher #=> #<ImageUploader::Attacher>
```

### `#<name>`

Calls `Attacher#get`, which returns an `UploadedFile` object instantiated from
attachment data.

```rb
photo = Photo.new(image_data: '{"id":"foo.jpg","storage":"store","metadata":{...}}')
photo.image             #=> #<ImageUploader::UploadedFile>
photo.image.id          #=> "foo.jpg"
photo.image.storage_key #=> :store
photo.image.metadata    #=> { ... }
```

If no file is attached, `nil` is returned.

```rb
photo = Photo.new(image_data: nil)
photo.image #=> nil
```

### `#<name>_url`

Calls `Attacher#url`, which returns the URL to the attached file.

```rb
photo = Photo.new(image_data: {"id":"foo.jpg","storage":"...","metadata":{...}})
photo.image_url #=> "https://example.com/foo.jpg"
```

If no file is attached, `nil` is returned.

```rb
photo = Photo.new(image_data: nil)
photo.image_url #=> nil
```

### `#<name>_attacher`

Calls `Attacher.from_entity`, which returns an `Attacher` instance backed by
the entity object.

```rb
photo = Photo.new
photo.image_attacher           #=> #<ImageUploader::Attacher>
photo.image_attacher.record    #=> #<Photo>
photo.image_attacher.name      #=> :image
photo.image_attacher.attribute #=> :image_data
```

## Attacher

### `.from_entity`

The `Attacher.from_entity` method can be used for creating an `Attacher`
instance backed by the entity object.

```rb
photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')

attacher = ImageUploader::Attacher.from_entity(photo, :image)
attacher.record    #=> #<Photo>
attacher.name      #=> :image
attacher.attribute #=> :image_data

attacher.file #=> #<ImageUploader::UploadedFile>
```

Any additional options are forwarded to `Attacher#initialize`.

```rb
ImageUploader::Attacher.from_entity(photo, :image, cache: :other_cache)
```

### `#load_entity`

You can also load an entity into an existing attacher with
`Attacher#load_entity`.

```rb
photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')

attacher.file #=> nil
attacher.load_entity(photo, :image)
attacher.file #=> #<ImageUploader::UploadedFile>
```

### `#reload`

The `Attacher#reload` method reloads attached file from the attachment data on
the entity attribute.

```rb
photo = Photo.new

attacher = ImageUploader::Attacher.from_entity(photo, :image)
attacher.file #=> nil

photo.image_data = '{"id":"...","storage":"...","metadata":{...}}'

attacher.file #=> nil
attacher.reload
attacher.file #=> #<ImageUploader::UploadedFile>
```

### `#column_values`

The `Attacher#column_values` method returns a hash with the entity attribute as
key and current attachment data as value.

```rb
attacher = ImageUploader::Attacher.from_entity(Photo.new, :image)
attacher.attach(io)

attacher.column_values #=> { :image_data => '{"id":"...","storage":"...","metadata":{...}}' }
```

### `#attribute`

The `Attacher#attribute` method returns the entity attribute from which
attached file data is read.

```rb
attacher = ImageUploader::Attacher.from_entity(Photo.new, :image)
attacher.attribute #=> :image_data
```

### `#record`

The `Attacher#record` method returns the entity instance from which the
attacher was loaded.

```rb
attacher = ImageUploader::Attacher.from_entity(Photo.new, :image)
attacher.record #=> #<Photo>
```

### `#name`

The `Attacher#name` method returns the name of the attachment from which the
attacher was loaded.

```rb
attacher = ImageUploader::Attacher.from_entity(Photo.new, :image)
attacher.name #=> :image
```

## Serialization

By default, attachment data is serialized into JSON using the `JSON` standard
library. If you want to change how data is serialized, see the
[`column`][column] plugin docs.

[entity]: /lib/shrine/plugins/entity.rb
[column]: /doc/plugins/column.md#readme
