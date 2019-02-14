# Delete Promoted

The [`delete_promoted`][delete_promoted] plugin deletes files that have been
promoted, after the record is saved. This means that cached files handled by
the attacher will automatically get deleted once they're uploaded to store.
This also applies to any other uploaded file passed to `Attacher#promote`.

```rb
plugin :delete_promoted
```

[delete_promoted]: /lib/shrine/plugins/delete_promoted.rb
