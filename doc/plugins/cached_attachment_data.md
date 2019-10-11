---
title: Cached Attachment Data
---

The [`cached_attachment_data`][cached_attachment_data] plugin adds the ability
to retain the cached file across form redisplays, which means the file doesn't
have to be reuploaded in case of validation errors.

```rb
plugin :cached_attachment_data
```

The plugin adds `#cached_<attachment>_data` to the model, which returns the
cached file as JSON, and should be used to set the value of the hidden form
field.

```rb
photo.cached_image_data #=> '{"id":"38k25.jpg","storage":"cache","metadata":{...}}'
```

This method delegates to `Attacher#cached_data`:

```rb
attacher.cached_data #=> '{"id":"38k25.jpg","storage":"cache","metadata":{...}}'
```

[cached_attachment_data]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/cached_attachment_data.rb
