# upload_options

The `upload_options` plugin allows you to automatically pass additional upload
options to storage on every upload:

```rb
plugin :upload_options, cache: { acl: "private" }
```

Keys are names of the registered storages, and values are either hashes or
blocks.

```rb
plugin :upload_options, store: -> (io, context) do
  if [:original, :thumb].include?(context[:version])
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
