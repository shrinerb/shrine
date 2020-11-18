---
title: Entity
---

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

These methods read attachment data from the `#<name>_data` attribute on the
entity instance.

```rb
class Photo < Entity(:image_data) # has `image_data` reader
  include ImageUploader::Attachment(:image)
end
```
```rb
photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')
photo.image          #=> #<ImageUploader::UploadedFile>
photo.image_url      #=> "https://example.com/image.jpg"
photo.image_attacher #=> #<ImageUploader::Attacher>
```

#### `#<name>`

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

#### `#<name>_url`

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

#### `#<name>_attacher`

Calls `Attacher.from_entity`, which returns an `Attacher` instance backed by
the entity object.

```rb
photo = Photo.new
photo.image_attacher           #=> #<ImageUploader::Attacher>
photo.image_attacher.record    #=> #<Photo>
photo.image_attacher.name      #=> :image
photo.image_attacher.attribute #=> :image_data
```

Any additional options will be forwarded to `Attacher#initialize`.

```rb
photo    = Photo.new
attacher = photo.image_attacher(cache: :other_cache)
attacher.cache_key #=> :other_cache
```

You can also specify default attacher options when including
`Shrine::Attachment`:

```rb
class Photo < Entity(:image_data)
  include ImageUploader::Attachment(:image, store: :other_store)
end
```
```rb
photo    = Photo.new
attacher = photo.image_attacher
attacher.store_key #=> :other_store
```

You can retrieve an `Attacher` instance from the entity *class* as well. In
this case it will not be initialized with any entity instance.

```rb
attacher = Photo.image_attacher
attacher #=> #<ImageUploader::Attacher>
attacher.record #=> nil
attacher.name   #=> nil

attacher = Photo.image_attacher(store: :other_store)
attacher.store_key #=> :other_store
```

## Attacher

You can also use `Shrine::Attacher` directly (with or without the
`Shrine::Attachment` module):

```rb
class Photo < Entity(:image_data) # has `image_data` reader
end
```
```rb
photo    = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')
attacher = ImageUploader::Attacher.from_entity(photo, :image)

attacher.file #=> #<Shrine::UploadedFile id="bc2e13.jpg" storage=:store ...>

attacher.attach(file)
attacher.file          #=> #<Shrine::UploadedFile id="397eca.jpg" storage=:store ...>
attacher.column_values #=> { image_data: '{"id":"397eca.jpg","storage":"store","metadata":{...}}' }

photo    = Photo.new(attacher.column_values)
attacher = ImageUploader::Attacher.from_entity(photo, :image)

attacher.file #=> #<Shrine::UploadedFile id="397eca.jpg" storage=:store ...>
```

### Loading entity

The `Attacher.from_entity` method can be used for creating an `Attacher`
instance backed by an entity object.

```rb
photo    = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')
attacher = ImageUploader::Attacher.from_entity(photo, :image)

attacher.record    #=> #<Photo>
attacher.name      #=> :image
attacher.attribute #=> :image_data

attacher.file #=> #<ImageUploader::UploadedFile>
```

Any additional options are forwarded to `Attacher#initialize`.

```rb
attacher = ImageUploader::Attacher.from_entity(photo, :image, cache: :other_cache)
attacher.cache_key #=> :other_cache
```

You can also load an entity into an existing attacher with
`Attacher#load_entity`.

```rb
photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')

attacher.load_entity(photo, :image)
attacher.record #=> #<Photo>
attacher.name   #=> :image
attacher.file   #=> #<ImageUploader::UploadedFile>
```

Or just `Attacher#set_entity` if you don't want to load attachment data:

```rb
photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')

attacher.set_entity(photo, :image) # doesn't load attachment data
attacher.record #=> #<Photo>
attacher.name   #=> :image
attacher.file   #=> nil
```

### Reloading

The `Attacher#reload` method reloads attached file from the attachment data on
the entity attribute and resets dirty tracking.

```rb
photo = Photo.new

attacher = ImageUploader::Attacher.from_entity(photo, :image)
attacher.file #=> nil

photo.image_data = '{"id":"...","storage":"...","metadata":{...}}'

attacher.file #=> nil
attacher.reload
attacher.file #=> #<ImageUploader::UploadedFile>
```

If you want to reload attachment data while retaining dirty tracking state, use
`Attacher#read` instead.

### Column values

The `Attacher#column_values` method returns a hash with the entity attribute as
key and current attachment data as value.

```rb
attacher = ImageUploader::Attacher.from_entity(Photo.new, :image)
attacher.attach(io)

attacher.column_values #=> { :image_data => '{"id":"...","storage":"...","metadata":{...}}' }
```

The `Attacher#attribute` method returns just the entity attribute from which
attached file data is read.

```rb
attacher = ImageUploader::Attacher.from_entity(Photo.new, :image)
attacher.attribute #=> :image_data
```

### Entity data

The `Attacher#record` method returns the entity instance from which the
attacher was loaded.

```rb
attacher = ImageUploader::Attacher.from_entity(Photo.new, :image)
attacher.record #=> #<Photo>
```

The `Attacher#name` method returns the name of the attachment from which the
attacher was loaded.

```rb
attacher = ImageUploader::Attacher.from_entity(Photo.new, :image)
attacher.name #=> :image
```

## Serialization

By default, attachment data is serialized into JSON using the `JSON` standard
library. If you want to change how data is serialized, see the
[`column`][column serializer] plugin docs.

[entity]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/entity.rb
[column]: https://shrinerb.com/docs/plugins/column
[column serializer]: https://shrinerb.com/docs/plugins/column#serializer
