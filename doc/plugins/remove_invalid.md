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
photo.image = file # invalid file
photo.valid?       #=> false
photo.image        #=> nil
```

[remove_invalid]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/remove_invalid.rb
