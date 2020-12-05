---
title: Model
---

The [`model`][model] plugin provides integration for handling attachment on
mutable structs. It is built on top of the [`entity`][entity] plugin.

```rb
plugin :model
```

## Attachment

Including a `Shrine::Attachment` module into a model class will:

* add [entity] attachment methods
* add `#<name>=` and `#<name>_changed?` methods

```rb
class Photo
  attr_accessor :image_data

  include ImageUploader::Attachment(:image)
end
```
```rb
photo = Photo.new

photo.image = file

photo.image      #=> #<Shrine::UploadedFile id="bc2e13.jpg" storage=:cache ...>
photo.image_data #=> '{"id":"bc2e13.jpg","storage":"cache","metadata":{...}}'

photo.image_attacher.finalize

photo.image      #=> #<Shrine::UploadedFile id="397eca.jpg" storage=:store ...>
photo.image_data #=> '{"id":"397eca.jpg","storage":"store","metadata":{...}}'
```

#### `#<name>=`

Calls `Attacher#assign` by default, which uploads the file to temporary storage
and attaches it, updating the model attribute.

```rb
photo = Photo.new
photo.image = file
photo.image.storage_key #=> :cache
photo.image_data        #=> '{"id":"...","storage":"cache","metadata":{...}}'
```

#### `#<name>_changed?`

Calls `Attacher#changed?` which returns whether the attachment has changed.

```rb
photo = Photo.new
photo.image_changed? #=> false
photo.image = file
photo.image_changed? #=> true
```

#### Disabling caching

If you don't want to use temporary storage, you can have `#<name>=` upload
directly to permanent storage.

```rb
plugin :model, cache: false
```
```rb
photo = Photo.new
photo.image = file
photo.image.storage_key #=> :store
photo.image_data        #=> '{"id":"...","storage":"store","metadata":{...}}'
```

This can be configured on the attacher level as well:

```rb
photo = Photo.new
photo.image_attacher(model_cache: false)
photo.image = file
photo.image.storage_key #=> :store
```

#### `#<name>_attacher`

Returns an `Attacher` instance backed by the model instance, memoized in an
instance variable.

```rb
photo = Photo.new
photo.image_attacher #=> #<ImageUploader::Attacher> (memoizes the instance)
photo.image_attacher #=> #<ImageUploader::Attacher> (returns memoized instance)
```

When attacher options are passed, the attacher instance is refreshed:

```rb
photo = Photo.new
photo.image_attacher(cache: :other_cache)
photo.image_attacher.cache_key #=> :other_cache
```

### Entity

If you still want to include `Shrine::Attachment` modules to immutable
entities, you can disable "model" behaviour by passing `model: false`:

```rb
class Photo
  attr_reader :image_data

  include ImageUploader::Attachment(:image, model: false)
end
```

## Attacher

You can also use `Shrine::Attacher` directly (with or without the
`Shrine::Attachment` module):

```rb
class Photo
  attr_accessor :image_data
end
```
```rb
photo    = Photo.new
attacher = ImageUploader::Attacher.from_model(photo, :image)

attacher.assign(file) # cache

attacher.file    #=> #<Shrine::UploadedFile id="bc2e13.jpg" storage=:cache ...>
photo.image_data #=> '{"id":"bc2e13.jpg","storage":"cache","metadata":{...}}'

attacher.finalize # promote

attacher.file    #=> #<Shrine::UploadedFile id="397eca.jpg" storage=:store ...>
photo.image_data #=> '{"id":"397eca.jpg","storage":"store","metadata":{...}}'
```

### Loading model

The `Attacher.from_model` method can be used for creating an `Attacher`
instance backed by a model object.

```rb
photo    = Photo.new
attacher = ImageUploader::Attacher.from_model(photo, :image)

attacher.record    #=> #<Photo>
attacher.name      #=> :image
attacher.attribute #=> :image_data

attacher.attach(io)
photo.image_data #=> '{"id":"...","storage":"...","metadata":{...}}'
```

You can also load an entity into an existing attacher with
`Attacher#load_model`.

```rb
photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')

attacher.file #=> nil
attacher.load_model(photo, :image)
attacher.file #=> #<ImageUploader::UploadedFile>
```

Or just `Attacher#set_model` if you don't want to load attachment data:

```rb
photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')

attacher.file #=> nil
attacher.set_model(photo, :image) # doesn't load attachment data
attacher.file #=> nil
```

### Writing attachment data

The `Attacher#write` method writes attachment data to the `#<name>_data`
attribute on the model instance.

```rb
photo    = Photo.new
attacher = ImageUploader::Attacher.from_model(photo, :image)

attacher.file = uploaded_file
photo.image_data #=> nil

attacher.write
photo.image_data #=> '{"id":"...","storage":"...","metadata":{...}}'
```

The `Attacher#write` method is automatically called on `Attacher#set`, as well
as `Attacher#assign`, `Attacher#attach_cached`, `Attacher#attach`,
`Attacher#promote` and any other attacher method that calls `Attacher#set`.

## Serialization

By default, attachment data is serialized into JSON using the `JSON` standard
library. If you want to change how data is serialized, see the
[`column`][column serializer] plugin docs.

[model]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/model.rb
[entity]: https://shrinerb.com/docs/plugins/entity
[column serializer]: https://shrinerb.com/docs/plugins/column#serializer
