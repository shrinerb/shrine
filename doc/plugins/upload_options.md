---
title: Upload Options
---

The [`upload_options`][upload_options] plugin allows you to automatically pass
additional upload options to storage on every upload:

```rb
plugin :upload_options, cache: { acl: "private" }
```

Keys are names of the registered storages, and values are either hashes or
blocks.

```rb
plugin :upload_options, store: -> (io, options) do
  if options[:derivative]
    { acl: "public-read" }
  else
    { acl: "private" }
  end
end
```

If you're uploading the file directly, you can also pass `:upload_options` to
the uploader.

```rb
uploader.upload(file, upload_options: { acl: "public-read" })
```

If storage keys are generated dynamically (e.g. via the
[`dynamic_storage`][dynamic_storage] plugin), it's not possible to list every
storage key upfront. In that case you can use a `Regexp` instead, which will
be matched against the storage key:

```rb
plugin :upload_options, /_store\z/ => { acl: "private" }
```

An exact storage key match always takes precedence over a `Regexp` match.

[upload_options]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/upload_options.rb
[dynamic_storage]: https://shrinerb.com/docs/plugins/dynamic_storage
