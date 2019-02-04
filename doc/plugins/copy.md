# Copy

The `copy` plugin allows copying attachment from one record to another.

```rb
plugin :copy
```

It adds a `Attacher#copy` method, which accepts another attacher, and copies
the attachment from it:

```rb
photo.image_attacher.copy(other_photo.image_attacher)
```

This method will automatically be called when the record is duplicated:

```rb
duplicated_photo = photo.dup
duplicated_photo.image #=> #<Shrine::UploadedFile>
duplicated_photo.image != photo.image
```
