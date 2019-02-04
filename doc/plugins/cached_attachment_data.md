# Cached Attachment Data

The `cached_attachment_data` plugin adds the ability to retain the cached file
across form redisplays, which means the file doesn't have to be reuploaded in
case of validation errors.

```rb
plugin :cached_attachment_data
```

The plugin adds `#cached_<attachment>_data` to the model, which returns the
cached file as JSON, and should be used to set the value of the hidden form
field.

```rb
@user.cached_avatar_data #=> '{"id":"38k25.jpg","storage":"cache","metadata":{...}}'
```

This method delegates to `Attacher#read_cached`:

```rb
attacher.read_cached #=> '{"id":"38k25.jpg","storage":"cache","metadata":{...}}'
```
