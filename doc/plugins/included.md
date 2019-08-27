# Included

The [`included`][included] plugin allows you to hook up to the `.included` hook
of the attachment module, and call additional methods on the model that
includes it.

```rb
plugin :included do |name|
  # called when attachment module is included into a model

  self #=> #<Photo>
  name #=> :image
end
```
```rb
Photo.include Shrine::Attachment(:image)
```

[included]: /lib/shrine/plugins/included.rb
