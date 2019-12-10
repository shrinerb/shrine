---
title: Remove Invalid
---

The [`remove_invalid`][remove_invalid] plugin automatically deletes and
deassigns a new assigned file if it was invalid. If there was a previous file
attached, it will be assigned back.

```rb
plugin :remove_invalid
```

```rb
# without previous file
photo.image        #=> nil
photo.image = file # validation fails, assignment is reverted
photo.valid?       #=> false
photo.image        #=> nil

# with previous file
photo.image        #=> #<Shrine::UploadedFile id="foo" ...>
photo.image = file # validation fails, assignment is reverted
photo.valid?       #=> false
photo.image        #=> #<Shrine::UploadedFile id="foo" ...>
```

[remove_invalid]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/remove_invalid.rb
