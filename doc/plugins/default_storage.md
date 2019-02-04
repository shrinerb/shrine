# Default Storage

The `default_storage` plugin enables you to change which storages are going to
be used for this uploader's attacher (the default is `:cache` and `:store`).

```rb
plugin :default_storage, cache: :special_cache, store: :special_store
```

You can also pass a block and choose the values depending on the record values
and the name of the attachment. This is useful if you're using the
`dynamic_storage` plugin. Example:

```rb
plugin :default_storage, store: ->(record, name) { :"store_#{record.username}" }
```
