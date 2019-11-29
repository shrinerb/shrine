---
title: Allow Re-Assign
---

The [`allow_reassign`][allow_reassign] plugin ignores the exception when
assigning a stored file if it's the currently attached file. This is useful if
you want to treat the attachment attribute as a permanent attribute, to which
you can always assign the current attached file value.

```rb
plugin :allow_reassign
```
```rb
# with model:
photo.image #=> #<Shrine::UploadedFile id="foo" storage=:store metadata={...}>
photo.image = '{"id":"foo","storage":"store","metadata":{...}}' # no-op

# with attacher:
attacher.file #=> #<Shrine::UploadedFile id="foo" storage=:store metadata={...}>
attacher.assign '{"id":"foo","storage":"store","metadata":{...}}' # no-op

```

[allow_reassign]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/allow_reassign.rb
