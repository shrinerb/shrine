---
title: Keep Files
---

The [`keep_files`][keep_files] plugin prevents the attached file (and any of
its [derivatives]) from being deleted when the attachment would normally be
destroyed, which happens when the attachment is removed/replaced, or when the
record is deleted. This functionality is useful when implementing soft deletes,
versioning, or in general any scenario where you need to keep history.

```rb
plugin :keep_files
```
```rb
photo.image #=> #<Shrine::UploadedFile>
photo.destroy
photo.image.exists? #=> true
```

[keep_files]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/keep_files.rb
[derivatives]: https://shrinerb.com/docs/plugins/derivatives
