# Remove Invalid

The [`remove_invalid`][remove_invalid] plugin automatically deletes a new
assigned file if it was invalid and deassigns it from the record. If there was
a previous file attached, it will be assigned back, otherwise no attachment
will be assigned.

```rb
plugin :remove_invalid
```

[remove_invalid]: /lib/shrine/plugins/remove_invalid.rb
