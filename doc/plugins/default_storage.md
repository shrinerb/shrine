# Default Storage

The [`default_storage`][default_storage] plugin allows you to change the
default temporary and permanent storage a `Shrine::Attacher` object will use
(the default is `:cache` and `:store`).

```rb
plugin :default_storage, cache: :other_cache, store: :other_store
```

If you want the storage to be dynamic based on `Attacher` data, you can use a
block, and it will be evaluated in context of the `Attacher` instance:

```rb
plugin :default_storage, store: -> {
  if record.is_a?(Photo)
    :photo_store
  else
    :store
  end
}
```

You can also set default storage with `Attacher#default_cache` and
`Attacher#default_store`:

```rb
# default temporary storage
Attacher.default_cache :other_cache
# or
Attacher.default_cache { :other_cache }

# default permanent storage
Attacher.default_store :other_store
# or
Attacher.default_store { :other_store }
```

The dynamic block is useful in combination with the
[`dynamic_storage`][dynamic_storage] plugin.

[default_storage]: /lib/shrine/plugins/default_storage.rb
[dynamic_storage]: /doc/plugins/dynamic_storage.md#readme
