---
title: Allow Assign Current
---

The [`allow_assign_current`][allow_assign_current] plugin makes the attacher
silently skip assignment when the given uploaded file is the currently attached
file. This is useful if you want to treat the attachment attribute as a
permanent attribute, which isn't possible by default because the attacher
raises an exception when a non-cached file is assigned.

```rb
plugin :allow_assign_current
```
```rb
# with attacher:
attacher.file #=> #<Shrine::UploadedFile id="foo" storage=:store metadata={...}>
attacher.assign '{"id":"foo","storage":"store","metadata":{...}}' # no-op

# with model:
photo.image #=> #<Shrine::UploadedFile id="foo" storage=:store metadata={...}>
photo.image = '{"id":"foo","storage":"store","metadata":{...}}' # no-op
```

[allow_assign_current]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/allow_assign_current.rb
