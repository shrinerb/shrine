---
title: Ignore Assign Current
---

The [`ignore_assign_current`][ignore_assign_current] plugin makes the attacher
silently skip assignment when the given uploaded file is the currently attached
file. This is useful if you want to treat the attachment attribute as a
permanent attribute, which isn't possible by default because the attacher
raises an exception when a non-cached file is assigned.

```rb
plugin :ignore_assign_current
```
```rb
# with attacher:
attacher.file #=> #<Shrine::UploadedFile id="foo" storage=:store metadata={...}>
attacher.assign '{"id":"foo","storage":"store","metadata":{...}}' # no-op

# with model:
photo.image #=> #<Shrine::UploadedFile id="foo" storage=:store metadata={...}>
photo.image = '{"id":"foo","storage":"store","metadata":{...}}' # no-op
```

[ignore_assign_current]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/ignore_assign_current.rb
