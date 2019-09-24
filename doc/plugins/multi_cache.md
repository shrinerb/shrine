# Multi Cache

The [`multi_cache`][multi_cache] plugin allows an attacher to accept files from
additional temporary storages.

```rb
Shrine.storages = { cache: ..., cache_one: ..., cache_two: ..., store: ... }

Shrine.plugin :multi_cache, additional_cache: [:cache_one, :cache_two]
```
```rb
photo.image = { "id" => "...", "storage" => "cache", "metadata" => { ... } }
photo.image.storage_key #=> :cache
# or
photo.image = { "id" => "...", "storage" => "cache_one", "metadata" => { ... } }
photo.image.storage_key #=> :cache_one
# or
photo.image = { "id" => "...", "storage" => "cache_two", "metadata" => { ... } }
photo.image.storage_key #=> :cache_two
```

[multi_cache]: /lib/shrine/plugins/multi_cache.rb
