---
title: Remove Attachment
---

The [`remove_attachment`][remove_attachment] plugin allows you to delete
attachments through checkboxes on the web form.

```rb
plugin :remove_attachment
```

The plugin adds the `#remove_<name>` accessor to your model, which removes the
attached file if it receives a truthy value:

```rb
photo.image #=> #<Shrine::UploadedFile>
photo.remove_image = 'true'
photo.image #=> nil
```

This allows you to add a checkbox form field for removing attachments:

```rb
form_for photo do |f|
  # ...
  f.check_box :remove_image
end
```

If you're using the `Shrine::Attacher` directly, you can use the
`Attacher#remove` accessor:

```rb
attacher.file #=> #<Shrine::UploadedFile>
attacher.remove = '1'
attacher.file #=> nil
```

[remove_attachment]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/remove_attachment.rb
