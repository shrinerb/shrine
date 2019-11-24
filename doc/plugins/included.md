---
title: Included
---

The [`included`][included] plugin allows you to hook up to the `.included` hook
of the attachment module, and call additional methods on the model that
includes it.

```rb
class ImageUploader < Shrine
  plugin :included do |name|
    # called when attachment module is included into a model

    self #=> Photo (the model class)
    name #=> :image
  end
end
```
```rb
class Photo
  include ImageUploader::Attachment(:image) # triggers the included block
end
```

For example, you can use it to define additional methods on the model:

```rb
class ImageUploader < Shrine
  plugin :included do |name|
    define_method(:"#{name}_width")  { send(name)&.width  }
    define_method(:"#{name}_height") { send(name)&.height }
  end
end
```
```rb
photo = Photo.new(image: file)
photo.image_width  #=> 1200
photo.image_height #=> 800
```

[included]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/included.rb
