---
title: Restore Cached Data
---

The [`restore_cached_data`][restore_cached_data] plugin re-extracts metadata
when assigning already cached files, i.e. when the attachment has been retained
on validation errors or assigned from a direct upload. In both cases you may
want to re-extract metadata on the server side, mainly to prevent tempering,
but also in case of direct uploads to obtain metadata that couldn't be
extracted on the client side.

```rb
plugin :restore_cached_data
```
```rb
photo.image = { "id" => "path/to/image.jpg", "storage" => "cache", "metadata" => {} }
photo.image.metadata #=> { "size" => 4823763, "mime_type" => "image/jpeg", ... }
```

It uses the [`refresh_metadata`][refresh_metadata] plugin to re-extract
metadata.

[restore_cached_data]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/restore_cached_data.rb
[refresh_metadata]: https://shrinerb.com/docs/plugins/refresh_metadata
