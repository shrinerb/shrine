---
title: Form Assign
---

The [`form_assign`][form_assign] plugin allows attaching file from form params
without a form object.

```rb
plugin :form_assign
```

The `Attacher#form_assign` method will detect the file param and assign it to
the attacher:

```rb
attacher = photo.image_attacher
attacher.form_assign({ "image" => file, "title" => "...", "description" => "..." })
attacher.file #=> #<Shrine::UploadedFile>
```

It works with `remote_url`, `data_uri`, and `remove_attachment` plugins:

```rb
# remote_url plugin
attacher.form_assign({ "image_remote_url" => "https://example.com/..." })
attacher.file #=> #<Shrine::UploadedFile>
```
```rb
# data_uri plugin
attacher.form_assign({ "image_data_uri" => "data:image/jpeg;base64,..." })
attacher.file #=> #<Shrine::UploadedFile>
```
```rb
# remove_attachment plugin
attacher.form_assign({ "remove_image" => "1" })
attacher.file #=> nil
```

The return value is a hash with form params, with file param replaced with
cached file data, which can later be assigned again to the record.

```rb
attacher.form_assign({ "image" => file, "title" => "...", "description" => "..." })
#=> { :image => '{"id":"...","storage":"...","metadata":"..."}', "title" => "...", "description" => "..." }
```

You can also have attached file data returned as the `<name>_data` attribute,
suitable for persisting.

```rb
attacher.form_assign({ "image" => image, ... }, result: :attributes)
#=> { :image_data => '{"id":"...","storage":"...","metadata":"..."}', "title" => "...", "description" => "..." }
```

[form_assign]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/form_assign.rb
